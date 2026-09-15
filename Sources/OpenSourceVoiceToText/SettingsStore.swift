import Foundation
import AppKit
import Combine
import ServiceManagement

/// On-device Whisper models available for transcription. The raw value is the
/// folder name in the argmaxinc/whisperkit-coreml Hugging Face repo.
enum WhisperModel: String, CaseIterable, Identifiable {
    case largeV3Turbo = "openai_whisper-large-v3-v20240930_turbo_632MB"
    case small = "openai_whisper-small_216MB"
    case base = "openai_whisper-base"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .largeV3Turbo: return "Large v3 Turbo (recommended)"
        case .small: return "Small"
        case .base: return "Base"
        }
    }

    var sizeLabel: String {
        switch self {
        case .largeV3Turbo: return "~630 MB, best accuracy"
        case .small: return "~215 MB, good accuracy"
        case .base: return "~150 MB, fastest"
        }
    }
}

/// Available push-to-talk hotkeys. Raw values are persisted in UserDefaults.
enum Hotkey: String, CaseIterable, Identifiable {
    case rightOption
    case leftOption
    case rightCommand
    case rightShift
    case rightControl
    case fnGlobe
    case backtick
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
        case .backtick: return "Backtick `"
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
        case .backtick, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12: return false
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
        case .backtick: return 50 // ` / ~ key (ANSI)
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
    private let modelKey = "whisperModel"
    private let launchAtLoginKey = "launchAtLogin"
    private let showInDockKey = "showInDock"
    static let soundCuesKey = "soundCues"

    @Published var hotkey: Hotkey {
        didSet { defaults.set(hotkey.rawValue, forKey: hotkeyKey) }
    }

    @Published var model: WhisperModel {
        didSet { defaults.set(model.rawValue, forKey: modelKey) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: launchAtLoginKey)
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    /// Whether the app appears in the Dock. Applied live via activation policy.
    @Published var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: showInDockKey)
            Self.applyDockPolicy(showInDock)
        }
    }

    /// Audio blips on record start/stop/interruption. Read directly from
    /// UserDefaults by SoundCues so any code path can check it cheaply.
    @Published var soundCues: Bool {
        didSet { defaults.set(soundCues, forKey: Self.soundCuesKey) }
    }

    static func applyDockPolicy(_ show: Bool) {
        NSApp.setActivationPolicy(show ? .regular : .accessory)
    }

    init() {
        if let raw = defaults.string(forKey: hotkeyKey),
           let saved = Hotkey(rawValue: raw) {
            hotkey = saved
        } else {
            hotkey = .rightOption
        }
        if let raw = defaults.string(forKey: modelKey),
           let saved = WhisperModel(rawValue: raw) {
            model = saved
        } else {
            model = .largeV3Turbo
        }
        launchAtLogin = defaults.bool(forKey: launchAtLoginKey)
            && SMAppService.mainApp.status == .enabled
        if defaults.object(forKey: showInDockKey) == nil {
            showInDock = true
        } else {
            showInDock = defaults.bool(forKey: showInDockKey)
        }
        soundCues = defaults.object(forKey: Self.soundCuesKey) == nil
            ? true
            : defaults.bool(forKey: Self.soundCuesKey)

        // First run ever: default to launching at login, like the paid
        // apps — the whole point is muscle memory.
        if defaults.object(forKey: launchAtLoginKey) == nil {
            try? SMAppService.mainApp.register()
            launchAtLogin = SMAppService.mainApp.status == .enabled
            defaults.set(launchAtLogin, forKey: launchAtLoginKey)
        }
    }
}
