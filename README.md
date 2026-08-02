# Open Source Voice to Text

An open-source [Wispr Flow](https://wisprflow.ai) alternative for macOS: **hold a key, speak, release — your words are typed wherever your cursor is.** Transcription runs 100% on-device with [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Apple's CoreML-optimized Whisper port). No cloud, no account, no subscription.

<!-- TODO: add a screenshot or screen recording of the pill in action (docs/screenshot.png) -->

## Features

- **Hold-to-talk** — press and hold a hotkey to record, release to transcribe and insert
- **Floating pill UI** — a small capsule in the bottom-right corner of the screen, down in the empty wallpaper strip beside the Dock. The icon tells you everything: waveform (idle) · pulsing red dot (recording) · spinner (transcribing) · green check (pasted) · red triangle (error)
- **Fully local transcription** — Whisper `base` model via CoreML, fast on Apple Silicon; audio never leaves your Mac
- **Configurable hotkey** — Right Option (default), Left Option, Right Command, Right Shift, Right Control, Fn/Globe, or F5–F12
- **Paste anywhere** — text is pasted at the cursor in the focused app (copies to clipboard + synthesizes ⌘V)
- **Menu-bar-less background app** — no Dock icon (`LSUIElement`), just the pill

## Quick start

```bash
git clone https://github.com/oh-ashen-one/open-source-voice-to-text.git
cd open-source-voice-to-text
bash build.sh
open build/OpenSourceVoiceToText.app
```

That's it. Then:

1. Put your cursor in any text field, in any app.
2. **Hold the Right Option (⌥) key** — the pill shows a pulsing red dot.
3. Speak.
4. **Release the key** — a spinner appears, then the text lands at your cursor.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon recommended (WhisperKit uses CoreML/ANE; Intel works but is slower)
- Xcode / Swift toolchain to build from source
- ~150 MB disk + internet **once**, to download the Whisper model on first launch

## Permissions

On first use macOS will ask for:

- **Microphone** — required to record your voice.
- **Accessibility** — required for auto-paste (synthesizing ⌘V into other apps). If you decline, the app still works: transcribed text is copied to the clipboard and the pill shows an orange clipboard icon — paste manually with ⌘V.

Manage these any time under **System Settings → Privacy & Security → Microphone / Accessibility**, or from the pill's settings window.

### A note on code signing and permissions

macOS ties permission grants to an app's code signature. `build.sh` signs the app with your **Apple Development** certificate if one exists in your keychain (free — Xcode creates it when you sign in with an Apple ID), so permissions **persist across rebuilds**. If no identity is found it falls back to ad-hoc signing, which works but makes macOS re-ask for permissions after every rebuild. If permissions ever get confused (e.g. after switching signing identities), reset them with:

```bash
tccutil reset All com.opensource.voicetext
```

## First launch

The first time the app runs, it fetches the `openai_whisper-base` CoreML model (~150 MB) from Hugging Face (`argmaxinc/whisperkit-coreml`) — the pill shows a spinner while this happens. It's a one-time download; afterwards everything, including transcription, works fully offline.

## Changing the hotkey

Click the pill (or right-click it → **Settings…**) and pick a different key: Right/Left Option, Right Command, Right Shift, Right Control, Fn/Globe, or F5–F12. Your choice is persisted across launches. Right-click the pill → **Quit Voice to Text** to exit.

## Editing / contributing

This project is MIT-licensed — fork it, change it, make it yours. The codebase is deliberately small (~10 Swift files, no storyboards, no Xcode project — just a SwiftPM package and a build script), so it's easy to hack on directly or hand to an AI coding agent.

**Project layout:**

| Path | What it does |
| --- | --- |
| `Sources/OpenSourceVoiceToText/AppMain.swift` | Entry point, starts `NSApplication` |
| `Sources/OpenSourceVoiceToText/AppDelegate.swift` | Wires pill + hotkey + controller together |
| `Sources/OpenSourceVoiceToText/PillPanel.swift` | Floating pill window (position, size, SwiftUI view) |
| `Sources/OpenSourceVoiceToText/HotkeyManager.swift` | Global push-to-talk key monitoring |
| `Sources/OpenSourceVoiceToText/SettingsStore.swift` | Hotkey choices, persisted in `UserDefaults` |
| `Sources/OpenSourceVoiceToText/AudioRecorder.swift` | `AVAudioEngine` capture → 16 kHz mono samples |
| `Sources/OpenSourceVoiceToText/Transcriber.swift` | WhisperKit wrapper (model download + transcription) |
| `Sources/OpenSourceVoiceToText/AppController.swift` | State machine: idle → recording → transcribing → pasted |
| `Sources/OpenSourceVoiceToText/TextInserter.swift` | Clipboard + synthesized ⌘V |
| `Sources/OpenSourceVoiceToText/SettingsView.swift` | Settings window UI |
| `build.sh` | Build release → assemble `.app` → code-sign |

**Workflow:** edit the Swift files, run `bash build.sh`, relaunch with `open build/OpenSourceVoiceToText.app`. There are no tests yet — verification is "build is green + try the hotkey". Pull requests and issues are welcome.

## How it works

- **Hotkey**: global `NSEvent` monitors — `.flagsChanged` for modifier keys, `.keyDown`/`.keyUp` for F-keys (no Accessibility permission needed for monitoring)
- **Audio**: `AVAudioEngine` tap, resampled on the fly to 16 kHz mono `Float32`
- **Transcription**: WhisperKit, greedy decoding without timestamps for lowest latency
- **Insertion**: `NSPasteboard` + `CGEvent` ⌘V synthesis
- **UI**: SwiftUI pill hosted in a non-activating, floating `NSPanel`

## License

[MIT](LICENSE)
