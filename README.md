# Open Source Voice to Text

**Wispr Flow, free and open source.** Hold a key, speak, release — your words are typed wherever your cursor is. Transcription runs **100% on-device** with [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Apple's CoreML-optimized Whisper). No cloud, no account, no subscription.

- macOS 14+ · Apple Silicon recommended · MIT licensed
- Large v3 Turbo model by default — the same accuracy class as paid dictation apps
- ~900 lines of Swift, no Xcode project, one build script

---

## Give this repo to your AI agent

Paste this into Claude Code, Cursor, Kimi Code, Codex, or any coding agent:

```
Clone https://github.com/oh-ashen-one/open-source-voice-to-text,
run `bash build.sh`, then launch `build/OpenSourceVoiceToText.app`.
Tell me when the pill appears in the bottom-right corner of my screen.
```

Or do it yourself:

```bash
git clone https://github.com/oh-ashen-one/open-source-voice-to-text.git
cd open-source-voice-to-text
bash build.sh
open build/OpenSourceVoiceToText.app
```

Then:

1. Put your cursor in any text field, in any app.
2. **Hold the Right Option (⌥) key** — the pill shows a pulsing red dot.
3. Speak.
4. **Release the key** — a spinner appears, then the text lands at your cursor.

## Features

- **Hold-to-talk** — press and hold a hotkey to record, release to transcribe and insert
- **Paid-app accuracy** — Whisper Large v3 Turbo (~630 MB, CoreML/ANE-accelerated) is the default; Small (~215 MB) and Base (~150 MB) available in Settings for slower Macs
- **Floating pill UI** — a small capsule in the bottom-right corner. The icon tells you everything: waveform (idle) · pulsing red dot (recording) · spinner (transcribing/downloading) · green check (pasted) · orange clipboard (copied only) · red triangle (error)
- **Fully local** — audio never leaves your Mac; works offline after the one-time model download
- **Clipboard-safe** — pastes your dictation, then restores whatever you had copied before
- **No hallucinated text** — silence and background noise are detected and discarded instead of producing phantom "Thanks for watching!" output
- **Configurable hotkey** — Right Option (default), Left Option, Right Command, Right Shift, Right Control, Fn/Globe, or F5–F12
- **Launch at login** — one toggle in Settings
- **3-minute recording cap** — an accidentally held key stops itself
- **Paste anywhere** — text is pasted at the cursor in the focused app; without Accessibility permission it falls back to clipboard-only
- **Background app** — no Dock icon, no menu bar clutter, just the pill

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon recommended (WhisperKit uses CoreML/ANE; Intel works but is slower)
- Xcode / Swift toolchain to build from source (`xcode-select --install` is enough for the toolchain)
- ~650 MB disk + internet **once**, to download the default model on first launch

## Permissions

On first use macOS will ask for:

- **Microphone** — required to record your voice.
- **Accessibility** — required for auto-paste (synthesizing ⌘V into other apps). It is asked for **once**. If you decline, the app still works: transcribed text is copied to the clipboard and the pill shows an orange clipboard icon — paste manually with ⌘V.

Manage these any time under **System Settings → Privacy & Security → Microphone / Accessibility**, or from the pill's settings window (click the pill).

### A note on code signing and permissions

macOS ties permission grants to an app's code signature. `build.sh` signs the app with your **Apple Development** certificate if one exists in your keychain (free — Xcode creates it when you sign in with an Apple ID), so permissions **persist across rebuilds**. If no identity is found it falls back to ad-hoc signing, which works but makes macOS re-ask for permissions after every rebuild. If permissions ever get confused (e.g. after switching signing identities), reset them with:

```bash
tccutil reset All com.opensource.voicetext
```

## First launch

The first time the app runs, it fetches the Whisper Large v3 Turbo CoreML model (~630 MB) from Hugging Face (`argmaxinc/whisperkit-coreml`) — the pill shows "Downloading model…" while this happens. It's a one-time download; afterwards everything, including transcription, works fully offline.

## Settings

Click the pill (or right-click it → **Settings…**):

- **Hotkey** — Right/Left Option, Right Command, Right Shift, Right Control, Fn/Globe, or F5–F12. Persisted across launches.
- **Model** — Large v3 Turbo (recommended), Small, or Base. Switching downloads the new model once and uses it from then on.
- **Launch at login** — registers/unregisters the app as a login item.
- **Permissions** — live status + request buttons for Microphone and Accessibility.

Right-click the pill → **Quit Voice to Text** to exit.

## Editing / contributing

This project is MIT-licensed — fork it, change it, make it yours. The codebase is deliberately small (~10 Swift files, no storyboards, no Xcode project — just a SwiftPM package and a build script), so it's easy to hack on directly or hand to an AI coding agent.

**Project layout:**

| Path | What it does |
| --- | --- |
| `Sources/OpenSourceVoiceToText/AppMain.swift` | Entry point, starts `NSApplication` |
| `Sources/OpenSourceVoiceToText/AppDelegate.swift` | Wires pill + hotkey + controller together |
| `Sources/OpenSourceVoiceToText/PillPanel.swift` | Floating pill window (position, size, SwiftUI view) |
| `Sources/OpenSourceVoiceToText/HotkeyManager.swift` | Global push-to-talk key monitoring |
| `Sources/OpenSourceVoiceToText/SettingsStore.swift` | Hotkey, model and launch-at-login choices (`UserDefaults`) |
| `Sources/OpenSourceVoiceToText/AudioRecorder.swift` | `AVAudioEngine` capture → 16 kHz mono samples |
| `Sources/OpenSourceVoiceToText/Transcriber.swift` | WhisperKit wrapper (model download, silence gate, hallucination filter) |
| `Sources/OpenSourceVoiceToText/AppController.swift` | State machine: idle → recording → transcribing → pasted |
| `Sources/OpenSourceVoiceToText/TextInserter.swift` | Clipboard snapshot → paste → restore |
| `Sources/OpenSourceVoiceToText/SettingsView.swift` | Settings window UI |
| `build.sh` | Build release → assemble `.app` → code-sign |

**Workflow:** edit the Swift files, run `bash build.sh`, relaunch with `open build/OpenSourceVoiceToText.app`. There are no tests yet — verification is "build is green + try the hotkey". Pull requests and issues are welcome.

## How it works

- **Hotkey**: global `NSEvent` monitors — `.flagsChanged` for modifier keys, `.keyDown`/`.keyUp` for F-keys (no Accessibility permission needed for monitoring)
- **Audio**: `AVAudioEngine` tap, resampled on the fly to 16 kHz mono `Float32`
- **Transcription**: WhisperKit, greedy decoding without timestamps for lowest latency; RMS-based silence gate + hallucination blocklist on quiet input
- **Insertion**: snapshot clipboard → set text → `CGEvent` ⌘V synthesis → restore clipboard (skipped if the clipboard changed in the meantime)
- **UI**: SwiftUI pill hosted in a non-activating, floating `NSPanel`

## License

[MIT](LICENSE)
