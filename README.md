# Open Source Voice to Text

An open-source [Wispr Flow](https://wisprflow.ai) alternative for macOS: **hold a key, speak, release — your words are typed wherever your cursor is.** Transcription runs 100% on-device with [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Apple's CoreML-optimized Whisper port). No cloud, no account, no subscription.

<!-- TODO: add a screenshot or screen recording of the pill in action -->
![Screenshot placeholder](docs/screenshot.png)

## Features

- **Hold-to-talk** — press and hold a hotkey to record, release to transcribe and insert
- **Floating pill UI** — a small capsule hovering just above the Dock shows idle / recording (pulsing red dot + elapsed time) / transcribing state
- **Fully local transcription** — Whisper `base` model via CoreML, fast on Apple Silicon; audio never leaves your Mac
- **Configurable hotkey** — Right Option (default), Left Option, Right Command, Right Shift, Right Control, Fn/Globe, or F5–F12
- **Paste anywhere** — text is pasted at the cursor in the focused app (copies to clipboard + synthesizes ⌘V)
- **Menu-bar-less background app** — no Dock icon (`LSUIElement`), just the pill

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon recommended (WhisperKit uses CoreML/ANE; Intel works but is slower)
- Xcode / Swift toolchain to build from source
- ~150 MB disk + internet **once**, to download the Whisper model

## Build & Run

```bash
git clone https://github.com/oh-ashen-one/open-source-voice-to-text.git
cd open-source-voice-to-text
bash build.sh
open build/OpenSourceVoiceToText.app
```

`build.sh` compiles a release binary, assembles a real `OpenSourceVoiceToText.app` bundle, and ad-hoc code-signs it.

## Permissions

On first launch macOS will ask for:

- **Microphone** — required to record your voice.
- **Accessibility** — required for auto-paste (synthesizing ⌘V into other apps). If you decline, the app still works: transcribed text is copied to the clipboard and the pill shows "Copied to clipboard" — paste manually with ⌘V.

You can re-open these any time from the pill's settings window: **System Settings → Privacy & Security → Microphone / Accessibility**.

## First launch

The first time the app runs, the pill shows **"Downloading model…"** while it fetches the `openai_whisper-base` CoreML model (~150 MB) from Hugging Face (`argmaxinc/whisperkit-coreml`). This happens once; afterwards everything, including transcription, works fully offline.

## Usage

1. Put your cursor in any text field, in any app.
2. **Hold the Right Option (⌥) key** — the pill turns red and shows elapsed time.
3. Speak.
4. **Release the key** — the pill shows "Transcribing…", then the text appears at your cursor.

### Changing the hotkey

Click the pill (or right-click it → **Settings…**) and pick a different key: Right/Left Option, Right Command, Right Shift, Right Control, Fn/Globe, or F5–F12. Your choice is persisted across launches. Right-click the pill → **Quit Voice to Text** to exit.

## How it works

- **Hotkey**: global `NSEvent` monitors — `.flagsChanged` for modifier keys, `.keyDown`/`.keyUp` for F-keys (no Accessibility permission needed for monitoring)
- **Audio**: `AVAudioEngine` tap, resampled on the fly to 16 kHz mono `Float32`
- **Transcription**: WhisperKit, greedy decoding without timestamps for lowest latency
- **Insertion**: `NSPasteboard` + `CGEvent` ⌘V synthesis
- **UI**: SwiftUI pill hosted in a non-activating, floating `NSPanel`

## License

[MIT](LICENSE)
