import AppKit
import Combine

/// Menu bar (top-right) status item: mirrors the app's current state with
/// its icon and offers quick access to Settings and Quit.
@MainActor
final class MenuBarController: NSObject {
    var onOpenSettings: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var stateCancellable: AnyCancellable?

    init(controller: AppController) {
        super.init()

        let menu = NSMenu()
        menu.autoenablesItems = false
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Voice to Text", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        updateIcon(for: controller.state)
        stateCancellable = controller.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.updateIcon(for: state) }
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func updateIcon(for state: AppController.State) {
        let symbolName: String
        switch state {
        case .idle: symbolName = "waveform"
        case .recording: symbolName = "record.circle"
        case .transcribing, .downloadingModel: symbolName = "ellipsis.circle"
        case .pasted: symbolName = "checkmark.circle"
        case .copiedOnly: symbolName = "doc.on.clipboard"
        case .error: symbolName = "exclamationmark.triangle"
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Voice to Text")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
