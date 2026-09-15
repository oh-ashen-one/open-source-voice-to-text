import AppKit
import ApplicationServices
import Combine

/// Listens for the configured push-to-talk hotkey globally.
/// Modifier keys are observed via .flagsChanged (no special permission
/// required). Character/F-key hotkeys use a *consuming* CGEventTap when
/// Accessibility permission is granted, so the hotkey never types into the
/// focused app; without it they fall back to passive .keyDown/.keyUp
/// monitors (the hotkey character will then leak into the focused app).
final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private let settings: SettingsStore
    private var monitors: [Any] = []
    private var hotkeyCancellable: AnyCancellable?
    private var isPressed = false
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var tapUpgradeTimer: Timer?

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
        Log.info("hotkey: arming monitors for \(settings.hotkey.rawValue)")

        // Modifier-key hotkeys (passive is fine: modifiers type nothing)
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event)
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }) { monitors.append(l) }

        if settings.hotkey.isModifier { return }

        // Character/F-key hotkeys: prefer a consuming event tap so the
        // hotkey is swallowed instead of typed into the focused app.
        if setupEventTap() {
            Log.info("hotkey: consuming event tap active (hotkey will not type)")
        } else {
            Log.info("hotkey: no Accessibility permission — passive monitors, hotkey character will type into the focused app")
            armPassiveKeyMonitors()
            // Upgrade to the consuming tap as soon as the user grants
            // Accessibility in System Settings.
            tapUpgradeTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                guard let self, AXIsProcessTrusted() else { return }
                Log.info("hotkey: Accessibility granted — switching to consuming event tap")
                self.restart()
            }
        }
    }

    func stop() {
        tapUpgradeTimer?.invalidate()
        tapUpgradeTimer = nil
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            eventTapSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    private func restart() {
        start()
    }

    private func armPassiveKeyMonitors() {
        if let g = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] event in
            self?.handleKey(event)
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] event in
            self?.handleKey(event)
            return event
        }) { monitors.append(l) }
    }

    // MARK: - Consuming event tap

    private func setupEventTap() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleTapEvent(type: type, event: event)
            },
            userInfo: userInfo
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        eventTapSource = source
        return true
    }

    /// Returning nil consumes the event so it never reaches the focused app.
    private func handleTapEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables taps whose callback is too slow; re-arm ours.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }
        let hotkey = settings.hotkey
        guard !hotkey.isModifier, matches(hotkey: hotkey, event: event) else {
            return Unmanaged.passUnretained(event)
        }
        switch type {
        case .keyDown:
            // Holding the key generates repeats; swallow them all but only
            // treat the first one as a press.
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                update(pressed: true)
            }
        case .keyUp:
            update(pressed: false)
        default:
            break
        }
        return nil
    }

    private func matches(hotkey: Hotkey, event: CGEvent) -> Bool {
        if hotkey == .backtick {
            // Match by character rather than hardware keyCode: the `~ key
            // is keyCode 50 on ANSI keyboards but 10 on ISO layouts.
            return NSEvent(cgEvent: event)?.charactersIgnoringModifiers == "`"
        }
        return event.getIntegerValueField(.keyboardEventKeycode) == Int64(hotkey.keyCode)
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
        Log.info("hotkey: \(pressed ? "pressed" : "released")")
        if pressed {
            onPress?()
        } else {
            onRelease?()
        }
    }
}
