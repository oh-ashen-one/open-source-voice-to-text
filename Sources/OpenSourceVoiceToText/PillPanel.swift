import AppKit
import SwiftUI

/// Non-activating, floating, transparent panel hosting the pill SwiftUI view.
final class PillPanel: NSPanel {

    static let pillSize = NSSize(width: 220, height: 56)

    init(rootView: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: PillPanel.pillSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: PillPanel.pillSize)
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Bottom-center of the main screen, just above the Dock area.
    func positionAboveDock() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - PillPanel.pillSize.width / 2
        let y = visible.minY + 12
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// The pill UI: shows idle / downloading / recording / transcribing state.
struct PillView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var settings: SettingsStore
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            statusIndicator
            statusLabel
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(width: PillPanel.pillSize.width, height: PillPanel.pillSize.height)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture {
            if case .error = controller.state, !controller.modelReady {
                controller.prepare() // retry model download
            } else {
                onOpenSettings()
            }
        }
        .contextMenu {
            Button("Settings…", action: onOpenSettings)
            Divider()
            Button("Quit Voice to Text", action: onQuit)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch controller.state {
        case .downloadingModel:
            ProgressView()
                .controlSize(.small)
        case .idle:
            Image(systemName: "waveform")
                .foregroundStyle(.secondary)
        case .recording:
            PulsingDot()
        case .transcribing:
            ProgressView()
                .controlSize(.small)
        case .pasted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .copiedOnly:
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.orange)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch controller.state {
        case .downloadingModel:
            Text("Downloading model…")
                .foregroundStyle(.secondary)
        case .idle:
            Text("Hold \(settings.hotkey.displayName)")
                .foregroundStyle(.secondary)
        case .recording:
            RecordingTimer(start: controller.recordingStart)
        case .transcribing:
            Text("Transcribing…")
        case .pasted:
            Text("Pasted")
        case .copiedOnly:
            Text("Copied to clipboard")
        case .error(let message):
            Text(message)
                .lineLimit(2)
                .font(.caption)
        }
    }
}

/// Red dot with a pulse animation while recording.
private struct PulsingDot: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 12, height: 12)
            .scaleEffect(pulsing ? 1.35 : 0.85)
            .opacity(pulsing ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

/// Elapsed recording time, ticking every 0.1 s.
private struct RecordingTimer: View {
    let start: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(start ?? context.date))
            Text(String(format: "%.1f s", elapsed))
                .monospacedDigit()
                .foregroundStyle(.red)
        }
    }
}
