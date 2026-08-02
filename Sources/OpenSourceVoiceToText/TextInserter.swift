import AppKit
import ApplicationServices

/// Inserts transcribed text into the currently focused app:
/// copies to the pasteboard and synthesizes Cmd+V. Auto-paste requires
/// Accessibility permission; without it the text stays on the clipboard.
enum TextInserter {

    /// - Returns: true if the paste keystroke was synthesized, false if the
    ///   text was only copied to the clipboard (no Accessibility permission).
    @MainActor
    @discardableResult
    static func insert(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard ensureAccessibilityPermission() else { return false }

        let source = CGEventSource(stateID: .hidSystemState)
        // Virtual key code 0x09 = "V"
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        return true
    }

    /// Checks Accessibility trust, prompting the user once if not granted.
    static func ensureAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
