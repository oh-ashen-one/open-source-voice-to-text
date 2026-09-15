import SwiftUI
import AVFoundation
import ApplicationServices

/// Settings window: pick the push-to-talk hotkey, model, and see
/// permission status.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var controller: AppController

    var body: some View {
        Form {
            Section("Push to Talk") {
                Picker("Hotkey (hold to talk)", selection: $settings.hotkey) {
                    ForEach(Hotkey.allCases) { hotkey in
                        Text(hotkey.displayName).tag(hotkey)
                    }
                }
                Text("Hold the key, speak, release — the text is pasted at the cursor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Transcription Model") {
                Picker("Model", selection: $settings.model) {
                    ForEach(WhisperModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                HStack {
                    Text(settings.model.sizeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(controller.modelReady ? "Ready" : "Downloading…")
                        .font(.caption)
                        .foregroundStyle(controller.modelReady ? .green : .secondary)
                }
                Text("Runs 100% on-device. Downloaded from Hugging Face once, then works fully offline. Switching models re-downloads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Show in Dock", isOn: $settings.showInDock)
                Toggle("Sound cues", isOn: $settings.soundCues)
                Text("Blip when recording starts and stops, plus a warning sound if recording cuts off mid-sentence or nothing was captured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("The menu bar icon (top right) is always available for Settings and Quit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                permissionRow(
                    title: "Microphone",
                    granted: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
                    actionTitle: "Request…"
                ) {
                    AVCaptureDevice.requestAccess(for: .audio) { _ in }
                }
                permissionRow(
                    title: "Input Monitoring (hotkey)",
                    granted: InputMonitoring.isGranted,
                    actionTitle: "Request…"
                ) {
                    InputMonitoring.request()
                }
                Text("Input Monitoring lets the app see your hotkey presses in other apps. If you just granted it, quit and relaunch the app for it to take effect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                permissionRow(
                    title: "Accessibility (auto-paste)",
                    granted: AXIsProcessTrusted(),
                    actionTitle: "Open Settings…"
                ) {
                    _ = TextInserter.ensureAccessibilityPermission()
                }
                Text("Without Accessibility permission, text is copied to the clipboard instead of being pasted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 440)
    }

    private func permissionRow(
        title: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Button(actionTitle, action: action)
            }
        }
    }
}
