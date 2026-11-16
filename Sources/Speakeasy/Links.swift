import AppKit
import SwiftUI

/// Spoken links.
///
/// Save a name and what it stands for — "LinkedIn" and your profile address,
/// "email" and your email address — and saying the name followed by the word
/// "link" pastes the saved text instead: "you can find me at LinkedIn link"
/// becomes "you can find me at https://www.linkedin.com/in/you".
struct SavedLink: Codable, Identifiable, Equatable {
    var id = UUID()
    /// What you say, without the word "link": "LinkedIn", "portfolio", "email".
    var name: String
    /// What gets pasted.
    var value: String
}

enum Links {
    private static let storageKey = "savedLinks"

    /// Shown the first time, so it is obvious what goes where.
    private static let starters = [
        SavedLink(name: "LinkedIn", value: ""),
        SavedLink(name: "Portfolio", value: ""),
        SavedLink(name: "Email", value: ""),
        SavedLink(name: "GitHub", value: ""),
    ]

    static var saved: [SavedLink] {
        get {
            guard
                let data = UserDefaults.standard.data(forKey: storageKey),
                let links = try? JSONDecoder().decode([SavedLink].self, from: data)
            else { return starters }
            return links
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
        }
    }

    /// The dictation with every "<name> link" swapped for its saved text.
    /// Names with nothing saved against them are left exactly as spoken.
    static func apply(to text: String, links: [SavedLink] = saved) -> String {
        // Longest names first, so "work email" wins over "email".
        let usable = links
            .filter { !letters(of: $0.name).isEmpty && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { letters(of: $0.name).count > letters(of: $1.name).count }

        var result = text
        for link in usable {
            guard let regex = try? NSRegularExpression(pattern: pattern(for: link.name), options: [.caseInsensitive])
            else { continue }
            let value = link.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let mutable = NSMutableString(string: result)
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: mutable.length))
            for match in matches.reversed() {
                mutable.replaceCharacters(in: match.range, with: value)
            }
            result = mutable as String
        }
        return result
    }

    private static func letters(of name: String) -> [Character] {
        name.filter { $0.isLetter || $0.isNumber }.map { $0 }
    }

    /// Matches the name however the speech engine happens to write it —
    /// "LinkedIn", "linked in", "Linked-In"; "email", "e-mail", "e mail" —
    /// followed by the word "link".
    private static func pattern(for name: String) -> String {
        let spoken = letters(of: name)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: #"[\s-]?"#)
        // A "my" in front goes too: "reach me at my email link" should not
        // paste as "reach me at my you@example.com".
        return #"(?<![\p{L}\p{N}])(?:my\s+)?"# + spoken + #"[\s-]+link(?![\p{L}\p{N}])"#
    }
}

// MARK: - The window where links are saved

@MainActor
final class LinksWindowController: NSObject {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let created = NSWindow(contentViewController: NSHostingController(rootView: LinksView()))
            created.styleMask = [.titled, .closable]
            created.title = "Spoken Links"
            created.isReleasedWhenClosed = false
            created.center()
            window = created
        }
        Self.installEditMenu()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Speakeasy has no menu bar of its own, and without an Edit menu ⌘V, ⌘C,
    /// ⌘X and ⌘A do nothing in a text field. This one is never seen; it only
    /// makes those shortcuts work.
    private static func installEditMenu() {
        guard NSApp.mainMenu == nil else { return }
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let main = NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}

private struct LinksView: View {
    @State private var links = Links.saved
    @FocusState private var focused: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Spoken Links")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Text("Say a name followed by “link” while dictating and the saved text is pasted in its place — “you can find me at LinkedIn link”.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            VStack(spacing: 8) {
                ForEach($links) { $link in
                    HStack(spacing: 8) {
                        TextField("Name", text: $link.name)
                            .focused($focused, equals: link.id)
                            .frame(width: 110)
                        Text("link")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        TextField("What to paste", text: $link.value)
                        Button {
                            links.removeAll { $0.id == link.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove this link")
                        .accessibilityLabel("Remove \(link.name) link")
                    }
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(.top, 16)

            Button {
                let added = SavedLink(name: "", value: "")
                links.append(added)
                focused = added.id
            } label: {
                Label("Add Link", systemImage: "plus")
            }
            .padding(.top, 12)
        }
        .padding(22)
        .frame(width: 520)
        .onChange(of: links) { _, updated in
            Links.saved = updated
        }
    }
}
