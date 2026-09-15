import IOKit.hid

/// Input Monitoring permission (Privacy & Security → Input Monitoring).
/// Required on modern macOS for the global hotkey monitors to receive any
/// keyboard events at all — without it, NSEvent global monitors silently
/// deliver nothing.
enum InputMonitoring {

    static var isGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Triggers the system prompt (macOS asks only once per app).
    /// After granting, the app must be relaunched for monitors to start
    /// receiving events.
    @discardableResult
    static func request() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
}
