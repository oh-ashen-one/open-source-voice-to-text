import SwiftUI
import AVFoundation
import ApplicationServices

/// Settings window: pick the push-to-talk hotkey, see permission status.
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

            Section("Permissions") {
                permissionRow(
                    title: "Microphone",
                    granted: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
                    actionTitle: "Request…"
                ) {
                    AVCaptureDevice.requestAccess(for: .audio) { _ in }
                }
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

            Section("Model") {
                HStack {
                    Text("Whisper base (on-device)")
                    Spacer()
                    Text(controller.modelReady ? "Ready" : "Downloading…")
                        .foregroundStyle(controller.modelReady ? .green : .secondary)
                }
                Text("The model is downloaded from Hugging Face on first launch and runs fully offline afterwards.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
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
