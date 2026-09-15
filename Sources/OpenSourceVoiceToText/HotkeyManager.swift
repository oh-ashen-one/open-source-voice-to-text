import AppKit
import Combine

/// Listens for the configured push-to-talk hotkey globally.
/// Modifier keys are observed via .flagsChanged (no special permission
/// required); F-keys via .keyDown/.keyUp monitors.
final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private let settings: SettingsStore
    private var monitors: [Any] = []
    private var hotkeyCancellable: AnyCancellable?
    private var isPressed = false

    init(settings: SettingsStore) {
        self.settings = settings
        // Re-arm monitors only when the hotkey itself changes.
        hotkeyCancellable = settings.$hotkey
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.restart() }
    }

    deinit {
        hotkeyCancellable?.cancel()
        stop()
    }

    func start() {
        stop()
        isPressed = false

        // Modifier-key hotkeys
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event)
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }) { monitors.append(l) }

        // F-key hotkeys
        if let g = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] event in
            self?.handleKey(event)
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] event in
            self?.handleKey(event)
            return event
        }) { monitors.append(l) }
    }

    func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
    }

    private func restart() {
        start()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let hotkey = settings.hotkey
        guard hotkey.isModifier,
              event.keyCode == hotkey.keyCode,
              let flag = hotkey.modifierFlag else { return }

        // On press the flag is set; on release it is cleared.
        let pressed = event.modifierFlags.contains(flag)
        update(pressed: pressed)
    }

    private func handleKey(_ event: NSEvent) {
        let hotkey = settings.hotkey
        guard !hotkey.isModifier else { return }
        if hotkey == .backtick {
            // Match by character rather than hardware keyCode: the `~ key
            // is keyCode 50 on ANSI keyboards but 10 on ISO layouts.
            guard event.charactersIgnoringModifiers == "`" else { return }
        } else {
            guard event.keyCode == hotkey.keyCode else { return }
        }

        switch event.type {
        case .keyDown:
            guard !event.isARepeat else { return }
            update(pressed: true)
        case .keyUp:
            update(pressed: false)
        default:
            break
        }
    }

    private func update(pressed: Bool) {
        guard pressed != isPressed else { return }
        isPressed = pressed
        if pressed {
            onPress?()
        } else {
            onRelease?()
        }
    }
}
