# Speakeasy

A menu-bar dictation app for macOS. Press **⇧⌘S** in any app, talk, press it again, and what you said is pasted at the cursor. Everything runs on your Mac; no audio or text leaves it.

While you talk, a dancing beer mug appears beside the mouse pointer with a speech bubble showing your words as they are heard.

## Using it

| Do this | What happens |
| --- | --- |
| Press **⇧⌘S** | Dictation starts. The microphone is on only while you are dictating. |
| Press **⇧⌘S** again | Dictation stops and the text is pasted into the app in front. |
| Press **Esc** while dictating | The dictation is thrown away. |

A dictation left running stops itself after 10 minutes.

The menu-bar icon also has **Start Dictation**, **Speech Engine**, **Spoken Links…**, **Setup & Permissions…** and **Start at Login**.

### Spoken formats

Say one of these phrases anywhere in a dictation and the text is laid out to match. The phrase itself is removed.

| Say | You get |
| --- | --- |
| "email format" | An email: greeting, tidy paragraphs, sign-off and name |
| "text message format" | One short, casual message |
| "bullet point format" | One bullet per item |
| "numbered list format" | A numbered list |
| "formal letter format" | A dated, formal letter |
| "meeting notes format" | Notes, decisions and action items |

Formats also remove filler words and doubled words, and fix capitals, punctuation and clear grammar slips using the macOS grammar checker.

### Spoken links

In **Spoken Links…**, save a name and the text it stands for, such as "LinkedIn" and your profile address. Saying the name followed by "link" pastes the saved text: "find me at LinkedIn link" becomes "find me at https://www.linkedin.com/in/you".

## Speech engines

Pick one under **Speech Engine** in the menu.

| Engine | Model file | Notes |
| --- | --- | --- |
| Whisper Accurate (default) | `ggml-small.en.bin` | Most accurate, punctuated |
| Whisper Fast | `ggml-base.en.bin` | About three times quicker, a few more mistakes |
| Apple Dictation | none | Built into macOS; no automatic punctuation, but spoken "comma", "period" and "new paragraph" work |

A Whisper engine is offered only when its model file is present. Without either file, Speakeasy uses the Apple engine.

The live speech bubble is always fed by the Apple engine, because Whisper cannot report words mid-sentence. With a Whisper engine, the bubble is an unpunctuated draft and can differ slightly from the pasted text.

### Getting the Whisper models

The models are large, so they are not in this repository. Download them from the [whisper.cpp model collection](https://huggingface.co/ggerganov/whisper.cpp/tree/main) and put them in:

```
~/Library/Application Support/Speakeasy/Models/
```

## Building

Requirements:

- macOS 26 or later
- Xcode 26 or its command-line tools (Swift 6.2)

```bash
./build.sh
```

This produces `build/Speakeasy.app`. Open it, and the setup window walks through the two permissions:

- **Microphone**, to hear you.
- **Accessibility**, to press ⌘V in the app you are dictating into. Without it, the text is left on the clipboard for you to paste.

`build.sh` signs the app with your Apple Development certificate if you have one, so macOS keeps those permissions between rebuilds. Without a certificate the app is signed ad hoc and the permissions must be granted again after each rebuild.

### Installing

```bash
./install.sh
```

This builds the app, installs it as `/Applications/Speakeasy.app` (replacing any older copy), adds it to the Dock and puts a Speakeasy shortcut on the Desktop, then opens it. Run it again after each change; it leaves the Dock and Desktop icons alone once they exist.

### Whisper libraries

Speakeasy links [whisper.cpp](https://github.com/ggml-org/whisper.cpp) v1.9.5 as static libraries in `Vendor/whisper/lib`. The committed libraries were compiled on an **Intel** Mac (AVX2, FMA, F16C and Accelerate; Metal and Core ML off). On an Apple silicon Mac, or an Intel Mac without those instructions, rebuild them first:

```bash
Vendor/whisper/build-whisper.sh
```

The script needs CMake; its header comment shows a way to get it without a system-wide install.

## Project layout

| Path | What it holds |
| --- | --- |
| `Sources/Speakeasy/AppDelegate.swift` | Menu bar, shortcut, and the dictation state machine |
| `Sources/Speakeasy/Dictation.swift`, `Engine.swift`, `Whisper.swift` | Microphone capture and the speech engines |
| `Sources/Speakeasy/EmailFormat.swift`, `Links.swift` | Spoken formats and spoken links |
| `Sources/Speakeasy/TextInserter.swift` | Pasting at the cursor and restoring the clipboard |
| `Sources/Speakeasy/MugView.swift`, `MugOverlay.swift`, `Caption.swift` | The mug and its speech bubble |
| `Sources/Speakeasy/SetupWindow.swift` | First-run setup and permissions |
| `Sources/Speakeasy/DevTools.swift` | Checks that run without a microphone |
| `Sources/CWhisper` | C headers that expose whisper.cpp to Swift |
| `Vendor/whisper` | Prebuilt whisper.cpp libraries, their build script and licence |

### Developer checks

The built binary takes a few flags for testing without speaking:

```bash
build/Speakeasy.app/Contents/MacOS/Speakeasy --dev-transcribe sample.wav --realtime --engine whisperAccurate
```

`--engine` accepts `whisperAccurate`, `whisperFast` or `apple`. The other flags:

| Flag | What it does |
| --- | --- |
| `--dev-email "<text>"` | Prints what a dictation would be pasted as, spoken formats applied |
| `--dev-links "<text>"` | The same, with sample spoken links filled in |
| `--dev-render <folder>` | Writes still frames of the mug and the app icon as PNG files |
| `--dev-overlay` | Shows the overlay on its own |

## Licences

whisper.cpp is MIT licensed; see `Vendor/whisper/LICENSE`. Speakeasy itself has no licence file yet.
