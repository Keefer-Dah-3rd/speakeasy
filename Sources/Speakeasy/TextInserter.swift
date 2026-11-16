import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Puts dictated text into whatever app is in front, at the cursor.
///
/// It works the way you would by hand: put the text on the clipboard, press
/// Cmd-V, then put back whatever was on the clipboard before.
enum TextInserter {
    enum Outcome {
        case pasted
        case copiedOnly  // no Accessibility permission, so the text was left on the clipboard
    }

    private typealias Snapshot = [[NSPasteboard.PasteboardType: Data]]

    /// The user's own clipboard, held while a restore is still pending, so two
    /// dictations in quick succession can't lose it.
    private static var pendingOriginal: Snapshot?
    private static var restoreWork: DispatchWorkItem?

    @MainActor
    static func insert(_ dictated: String) async -> Outcome {
        let pasteboard = NSPasteboard.general

        guard Permissions.accessibility else {
            pasteboard.clearContents()
            pasteboard.setString(dictated, forType: .string)
            return .copiedOnly
        }

        let text = needsLeadingSpace() ? " " + dictated : dictated

        restoreWork?.cancel()
        let original = pendingOriginal ?? snapshot(pasteboard)
        pendingOriginal = original

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Tells clipboard managers not to keep this in their history.
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        let ourChange = pasteboard.changeCount

        await waitForModifiersToLift()
        pressCommandV()

        let work = DispatchWorkItem {
            // Only put the old clipboard back if nothing else has changed it.
            if pasteboard.changeCount == ourChange {
                restore(original, to: pasteboard)
            }
            pendingOriginal = nil
            restoreWork = nil
        }
        restoreWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        return .pasted
    }

    // MARK: Clipboard

    private static func snapshot(_ pasteboard: NSPasteboard) -> Snapshot {
        (pasteboard.pasteboardItems ?? []).map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                contents[type] = item.data(forType: type)
            }
            return contents
        }
    }

    private static func restore(_ snapshot: Snapshot, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let items = snapshot.map { contents in
            let item = NSPasteboardItem()
            for (type, data) in contents {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    // MARK: Keystroke

    /// If Command or Shift are still held from the shortcut, the paste would be
    /// read as a different shortcut, so wait briefly for them to be released.
    private static func waitForModifiersToLift() async {
        let held: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]
        for _ in 0..<40 {
            if CGEventSource.flagsState(.combinedSessionState).intersection(held).isEmpty {
                return
            }
            try? await Task.sleep(for: .milliseconds(15))
        }
    }

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // MARK: Spacing

    /// True when the cursor sits directly after a word or punctuation mark, so
    /// back-to-back dictations don't run together. Best effort: apps that don't
    /// report their text (many browser-based ones) simply get no extra space.
    private static func needsLeadingSpace() -> Bool {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.2)

        var focused: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
            let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return false }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.2)

        var selection: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selection) == .success,
            let selection, CFGetTypeID(selection) == AXValueGetTypeID()
        else { return false }

        var range = CFRange()
        guard AXValueGetValue(selection as! AXValue, .cfRange, &range), range.location > 0 else {
            return false
        }

        var previous = CFRange(location: range.location - 1, length: 1)
        guard let previousValue = AXValueCreate(.cfRange, &previous) else { return false }

        var result: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element, kAXStringForRangeParameterizedAttribute as CFString, previousValue, &result) == .success,
            let character = (result as? String)?.unicodeScalars.last
        else { return false }

        if CharacterSet.whitespacesAndNewlines.contains(character) { return false }
        if "([{\"'“‘/-".unicodeScalars.contains(character) { return false }
        return true
    }
}
