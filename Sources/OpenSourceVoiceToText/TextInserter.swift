import AppKit
import ApplicationServices

/// Inserts transcribed text into the currently focused app:
/// copies to the pasteboard and synthesizes Cmd+V. Auto-paste requires
/// Accessibility permission; without it the text stays on the clipboard.
/// The user's previous clipboard contents are restored shortly after paste.
enum TextInserter {

    private static let didPromptKey = "didPromptForAccessibility"

    /// - Returns: true if the paste keystroke was synthesized, false if the
    ///   text was only copied to the clipboard (no Accessibility permission).
    @MainActor
    @discardableResult
    static func insert(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general

        // Snapshot the clipboard so we can restore it after pasting —
        // dictation should not clobber whatever the user had copied.
        let saved = snapshot(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let changeCountAfterWrite = pasteboard.changeCount

        guard AXIsProcessTrusted() else {
            promptForAccessibilityOnce()
            return false
        }

        // Give the pasteboard write a beat to become visible to other
        // processes before the synthesized ⌘V arrives.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            postCommandV()
        }

        // Restore the previous clipboard once the paste has landed. If the
        // user (or a second dictation) changed the clipboard in the meantime,
        // leave it alone.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard pasteboard.changeCount == changeCountAfterWrite else { return }
            restore(saved, into: pasteboard)
        }
        return true
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        // Virtual key code 0x09 = "V"
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Clipboard snapshot / restore

    private typealias ClipboardSnapshot = [[String: Data]]

    private static func snapshot(_ pasteboard: NSPasteboard) -> ClipboardSnapshot {
        (pasteboard.pasteboardItems ?? []).map { item in
            var dict = [String: Data]()
            for type in item.types {
                // Skip Apple-internal transient types; they cannot be
                // meaningfully restored.
                if type.rawValue.hasPrefix("org.nspasteboard.") { continue }
                if let data = item.data(forType: type) {
                    dict[type.rawValue] = data
                }
            }
            return dict
        }
    }

    private static func restore(_ snapshot: ClipboardSnapshot, into pasteboard: NSPasteboard) {
        guard !snapshot.isEmpty else { return }
        pasteboard.clearContents()
        let items = snapshot.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    // MARK: - Accessibility permission

    /// Shows the system Accessibility prompt at most once per install;
    /// afterwards the user is directed to System Settings manually.
    static func promptForAccessibilityOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didPromptKey) else { return }
        defaults.set(true, forKey: didPromptKey)
        _ = ensureAccessibilityPermission()
    }

    /// Checks Accessibility trust, prompting the user if not granted.
    /// Used by the settings window's explicit "Request…" button.
    static func ensureAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
