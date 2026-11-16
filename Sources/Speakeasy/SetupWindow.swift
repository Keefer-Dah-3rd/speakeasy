import AppKit
import SwiftUI

/// The first-run window: says how Speakeasy works and walks through the two
/// permissions it needs. It reappears from the menu bar whenever you want it.
@MainActor
final class SetupWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model = SetupModel()

    func show(note: String? = nil) {
        model.note = note
        model.startWatching()

        if window == nil {
            let view = SetupView(model: model) { [weak self] in
                self?.window?.close()
            }
            let created = NSWindow(contentViewController: NSHostingController(rootView: view))
            created.styleMask = [.titled, .closable, .fullSizeContentView]
            created.titlebarAppearsTransparent = true
            created.title = "Speakeasy"
            created.titleVisibility = .hidden
            created.isReleasedWhenClosed = false
            created.isMovableByWindowBackground = true
            created.delegate = self
            created.center()
            window = created
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model.stopWatching()
    }
}

@MainActor
final class SetupModel: ObservableObject {
    @Published var microphone: MicPermission = Permissions.microphone
    @Published var accessibility = Permissions.accessibility
    @Published var note: String?

    let mug = MugModel()
    private var timer: Timer?
    private var ticks = 0

    var ready: Bool {
        microphone == .granted && accessibility
    }

    func startWatching() {
        refresh()
        guard timer == nil else { return }
        mug.restart()

        let created = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(created, forMode: .common)
        timer = created
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
        mug.stop()
    }

    private func tick() {
        ticks += 1
        // Pretend someone is talking so the mug shows off its moves.
        let t = Double(ticks) / 30
        mug.targetLevel = max(0, 0.45 + 0.4 * sin(t * 5.1) * sin(t * 1.3))
        mug.easeLevel()

        if ticks % 20 == 0 {
            refresh()
        }
    }

    private func refresh() {
        let mic = Permissions.microphone
        if mic != microphone { microphone = mic }
        let trusted = Permissions.accessibility
        if trusted != accessibility { accessibility = trusted }
    }

    func grantMicrophone() {
        switch Permissions.microphone {
        case .undetermined:
            Permissions.requestMicrophone { [weak self] _ in
                self?.refresh()
            }
        case .denied:
            Permissions.openMicrophoneSettings()
        case .granted:
            break
        }
    }

    func grantAccessibility() {
        // macOS shows its own prompt only once; after that, go straight to Settings.
        let askedKey = "askedForAccessibility"
        if UserDefaults.standard.bool(forKey: askedKey) {
            Permissions.openAccessibilitySettings()
        } else {
            UserDefaults.standard.set(true, forKey: askedKey)
            Permissions.promptAccessibility()
        }
    }
}

struct SetupView: View {
    @ObservedObject var model: SetupModel
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MugLiveView(model: model.mug)
                .frame(width: 150, height: 150)
                .accessibilityHidden(true)

            Text("Speakeasy")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Press ⇧⌘S in any app and say what you want to type.\nYour words appear beside the mug as you talk.\nPress ⇧⌘S again to paste them. Esc cancels.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 6)

            VStack(spacing: 10) {
                PermissionRow(
                    symbol: "mic.fill",
                    title: "Microphone",
                    detail: "So it can hear you. It listens only while the mug is dancing.",
                    granted: model.microphone == .granted,
                    buttonTitle: model.microphone == .denied ? "Open Settings" : "Allow",
                    action: model.grantMicrophone)

                PermissionRow(
                    symbol: "keyboard.fill",
                    title: "Accessibility",
                    detail: "So it can type your words into the app you're using.",
                    granted: model.accessibility,
                    buttonTitle: "Turn On",
                    action: model.grantAccessibility)
            }
            .padding(.top, 22)

            if let note = model.note {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }

            Button(action: close) {
                Text(model.ready ? "Start Dictating" : "Close")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 22)
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .frame(width: 430)
    }
}

private struct PermissionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let granted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if granted {
                Label("On", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                Button(buttonTitle, action: action)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
