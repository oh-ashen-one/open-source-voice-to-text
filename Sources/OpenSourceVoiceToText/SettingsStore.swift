import Foundation
import AppKit
import Combine

/// Available push-to-talk hotkeys. Raw values are persisted in UserDefaults.
enum Hotkey: String, CaseIterable, Identifiable {
    case rightOption
    case leftOption
    case rightCommand
    case rightShift
    case rightControl
    case fnGlobe
    case f5, f6, f7, f8, f9, f10, f11, f12

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rightOption: return "Right Option ⌥"
        case .leftOption: return "Left Option ⌥"
        case .rightCommand: return "Right Command ⌘"
        case .rightShift: return "Right Shift ⇧"
        case .rightControl: return "Right Control ⌃"
        case .fnGlobe: return "Fn / Globe 🌐"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        }
    }

    /// true if this hotkey is a modifier detected via .flagsChanged
    var isModifier: Bool {
        switch self {
        case .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12: return false
        default: return true
        }
    }

    /// Hardware key code (for modifier keys: the specific left/right variant).
    var keyCode: UInt16 {
        switch self {
        case .rightOption: return 0x3D
        case .leftOption: return 0x3A
        case .rightCommand: return 0x36
        case .rightShift: return 0x3C
        case .rightControl: return 0x3E
        case .fnGlobe: return 0x3F
        case .f5: return 96
        case .f6: return 97
        case .f7: return 98
        case .f8: return 100
        case .f9: return 101
        case .f10: return 109
        case .f11: return 103
        case .f12: return 111
        }
    }

    /// Modifier flag to test in NSEvent.modifierFlags (modifier keys only).
    var modifierFlag: NSEvent.ModifierFlags? {
        switch self {
        case .rightOption, .leftOption: return .option
        case .rightCommand: return .command
        case .rightShift: return .shift
        case .rightControl: return .control
        case .fnGlobe: return .function
        default: return nil
        }
    }
}

/// Persists user preferences.
final class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard
    private let hotkeyKey = "pushToTalkHotkey"

    @Published var hotkey: Hotkey {
        didSet { defaults.set(hotkey.rawValue, forKey: hotkeyKey) }
    }

    init() {
        if let raw = defaults.string(forKey: hotkeyKey),
           let saved = Hotkey(rawValue: raw) {
            hotkey = saved
        } else {
            hotkey = .rightOption
        }
    }
}
