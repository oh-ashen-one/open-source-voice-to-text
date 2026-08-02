import AppKit
import SwiftUI

/// Application delegate: sets up the floating pill, hotkey manager and
/// the transcription pipeline. Runs as an accessory app (no Dock icon).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pillPanel: PillPanel?
    private var settingsWindow: NSWindow?
    private let controller = AppController()
    private let settings = SettingsStore()
    private lazy var hotkeyManager = HotkeyManager(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

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

        // Kick off microphone permission + model download in the background.
        controller.prepare()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
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
