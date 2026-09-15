import AppKit
import SwiftUI

/// Application delegate: sets up the floating pill, hotkey manager and
/// the transcription pipeline. Runs as an accessory app (no Dock icon).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pillPanel: PillPanel?
    private var settingsWindow: NSWindow?
    private var menuBar: MenuBarController?
    private let settings = SettingsStore()
    private lazy var controller = AppController(settings: settings)
    private lazy var hotkeyManager = HotkeyManager(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock visibility per user preference (Info.plist starts us accessory).
        SettingsStore.applyDockPolicy(settings.showInDock)

        // Menu bar status item (top-right)
        let menuBar = MenuBarController(controller: controller)
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
        self.menuBar = menuBar
        // Floating pill UI
        let pillView = PillView(
            controller: controller,
            settings: settings,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        let panel = PillPanel(rootView: pillView)
        panel.positionBottomRight()
        panel.orderFrontRegardless()
        pillPanel = panel

        // Global push-to-talk hotkey
        hotkeyManager.onPress = { [weak self] in self?.controller.beginRecording() }
        hotkeyManager.onRelease = { [weak self] in self?.controller.endRecording() }
        hotkeyManager.start()

        // Without Input Monitoring permission the hotkey monitors receive
        // no events at all — prompt for it up front (once).
        if !InputMonitoring.isGranted {
            InputMonitoring.request()
        }

        // Kick off microphone permission + model download in the background.
        controller.prepare()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
    }

    /// Clicking the Dock icon (when shown) opens the settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openSettings() }
        return true
    }

    private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, controller: controller)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Voice to Text Settings"
            window.contentView = NSHostingView(rootView: view)
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
