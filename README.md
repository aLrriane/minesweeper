# Minesweeper App

A classic Minesweeper game built with Flutter, featuring three difficulty levels, a shovel/flag tool system, a radar-scan power-up, and sound effects.

This repository is the **enhanced** version of the game — see [Changelog](#changelog) and [What Changed](#what-changed) for how it evolved from the original base project.

## Features

- **Three difficulty levels** chosen from a slider on the main menu:
  - Easy — 9 x 9 board, 10 mines
  - Medium — 13 x 13 board, 30 mines
  - Hard — 16 x 16 board, 55 mines
- **Two tools** below the board:
  - **Shovel** — reveal a cell (also triggered by tapping).
  - **Flag** — place/remove a flag on a hidden cell (also available via long-press or right-click on desktop/web).
- **Right-click to flag** — on Windows desktop and web, right-clicking any hidden cell toggles a flag. The app disables the browser's native context menu on web so right-click always flags instead of showing the popup menu (see `disable_context_menu_web.dart`). Right-click is handled via a raw `Listener` on each cell (with `onLongPress` as a touch fallback), because `GestureDetector.onSecondaryTap` alone is unreliable on Windows desktop and Flutter web.
- **Android back-guard** — on Android, a mouse/emulator right-click is **converted by the OS into the system "back" action before Flutter ever sees it** (right-click = Back, middle-click = Home, is built into Android itself). The app therefore never receives the right-click event, so right-click-to-flag is **not possible on Android** — no app code can change this. To stop a right-click silently kicking the player back to the menu, the game screen is wrapped in `PopScope(canPop: false)`; any back attempt (right-click → back, back gesture, or the AppBar back button) now shows a "Leave game?" confirmation dialog instead. On Android, flag with **long-press** or the **Flag tool**.
- **Radar Scan** — a power-up that lets you peek at the number of mines touching any hidden cell without revealing it. You get **3 scans per game**. Results display on the cell for a few seconds.
- **Timer & mine counter** in the app bar.
- **Win/Lose detection** — the first tap is always safe, and mines are placed *after* your first reveal so you never lose on the first move.
- **Options menu** — Sound-Effect volume slider (0% – 100%).
- **Exit button** — closes the app on desktop/mobile; on web, prompts the user to close the tab (browsers block self-closing).

## How to Run

```bash
flutter pub get
flutter run
```

## Project Structure

```
lib/
  main.dart                      # App entry point, game logic & UI
  disable_context_menu_web.dart  # Web-only: blocks the browser right-click menu
  disable_context_menu_stub.dart # No-op stub for non-web platforms
assets/
  audio/                         # Sound effects (WAV)
```

> Note: the two `disable_context_menu_*` files work via a conditional import in `main.dart` — the web version uses `dart:html`, the stub is used everywhere else.

## What Changed

This game started as a single-file base project (`minesweeper_app`) and was later copied and enhanced into this version (`minesweeper_app1`). The table below lists every feature and which version it appears in.

| Feature | Base app (`minesweeper_app`) | Enhanced app (this repo) |
|---------|:---:|:---:|
| Difficulty slider (Easy / Medium / Hard) | ✔ | ✔ |
| 9x9 / 13x13 / 16x16 boards | ✔ | ✔ |
| Shovel & Flag tools | ✔ | ✔ |
| Long-press to flag | ✔ | ✔ |
| Right-click to flag | ✔ | ✔ |
| Radar Scan power-up (3 uses) | ✔ | ✔ |
| Timer & mine counter in app bar | ✔ | ✔ |
| Safe first tap (mines placed after first reveal) | ✔ | ✔ |
| Restart button | ✔ | ✔ |
| Win/lose end dialog | ✔ | ✔ |
| **Options menu (SFX volume slider)** | ✘ | ✔ |
| **Exit button with confirmation** | ✘ | ✔ |
| **Help dialog (Radar Scan instructions)** | ✘ | ✔ |
| **Browser context-menu disabled on web** | ✘ | ✔ |
| **Sound effects (dig / flag / win / defeat)** | ✘ | ✔ |
| **Audio volume control** | ✘ | ✔ |

### What's *not* changed

The following are identical in both versions — no modifications were made to the core gameplay logic:

- Board generation, mine placement & adjacent-mine counting.
- Flood-fill reveal logic (`_floodFill`) and safe-first-tap behavior.
- Win detection (`_checkWin`) and the mine counter/timer mechanics.
- The shovel/flag tool selection and radar-scan behavior.

## Changelog

| Change | Description |
|--------|-------------|
| **1st** | Original base app (`minesweeper_app`) created — a single-file Flutter Minesweeper with the difficulty slider, shovel/flag tools, Radar Scan power-up, timer, and win/lose dialogs. |
| **2nd** | Project copied to `minesweeper_app1` and UI enhancements added: Options menu with volume sliders, Exit button with confirmation dialog, Help dialog for Radar Scan, and web right-click context-menu disabling. |
| **3rd** | Audio system implemented: `audioplayers` package added, `assets/audio/` registered, four placeholder WAV files generated, and the `AudioManager` class rewired from debug-print stubs to real playback with error handling. |
| **4th** | Right-click flagging bug fixed: cells rewired to use a raw `Listener` for right-button clicks, because `GestureDetector.onSecondaryTap` was unreliable on Windows desktop and Flutter web. |
| **5th** | Android back-guard added: mouse/emulator right-click is converted to the OS "back" action on Android, so `GameScreen` was wrapped in `PopScope(canPop: false)` with a "Leave game?" confirmation to prevent instant navigation back to the menu. |
| **6th** | Victory jingle added: `assets/audio/win.wav` generated and `playWinSound()` wired into the win path when the board is cleared. |
| **7th** | Defeat jingle added: `assets/audio/defeat.wav` generated and `playDefeatSound()` plays ~500 ms after the explosion when the player loses. |
| **8th** | Audio cleanup: background music and explosion sound removed entirely; dig and defeat volumes reduced to 50% of SFX volume for better balance; defeat jingle now plays on a dedicated `AudioPlayer` so it never cuts off other sounds; Options dialog simplified to a single SFX volume slider. |

> Changes are listed in the order they were made. The project is not under git version control.

## Audio System

Playback is centralized in a single `AudioManager` singleton (defined at the top of `lib/main.dart`), built on the **[audioplayers](https://pub.dev/packages/audioplayers)** package (`^6.1.0`). It uses two dedicated `AudioPlayer` instances:

- `_defeatPlayer` — serves the defeat jingle on its own channel so it can overlap other sounds without cutting them off.
- `_sfxPlayer` — all other one-shot sound effects (dig, flag, win).

### Sound triggers

| Event | Method | Asset |
|-------|--------|-------|
| Successful dig | `playDigSound()` | `assets/audio/dig.wav` |
| Flag placed | `playFlagSound()` | `assets/audio/flag.wav` |
| **Game lost (defeat jingle)** | **`playDefeatSound()`** | **`assets/audio/defeat.wav`** |
| **Board cleared (win)** | **`playWinSound()`** | **`assets/audio/win.wav`** |

### Volume handling

- SFX volume changes only affect sounds played **after** the slider moves (already-playing sounds are not adjusted).
- The dig and defeat effects play at **50%** of the SFX volume so they sit quieter than the flag and win sounds.

### Error handling & resource management

- Every audio call is wrapped in a `try/catch` that logs failures with `debugPrint` — audio problems can never crash the game.
- All call sites use fire-and-forget (no `await`), which is safe because errors are handled inside `AudioManager`.
- An `AudioManager.dispose()` method releases the native resources held by both players on app shutdown.

### Customizing the sounds

Replace any file in `assets/audio/` with your own `.wav` (or `.mp3`) file of the same name. For example, drop in a real `defeat.mp3` and update the `AssetSource('audio/defeat.wav')` string inside `playDefeatSound()` in `lib/main.dart`.

The bundled `.wav` files are simple programmatically-generated placeholder tones — perfect for confirming audio works, but you'll want to swap in real sounds for a polished experience. The win jingle (`win.wav`) is a generated ascending C-major arpeggio; the defeat jingle (`defeat.wav`) is a descending "sad trombone" sequence.

> **Audio file size note:** `audioplayers` enforces no hard limit, but keep each file under ~1–2 MB as a practical guideline. Audio assets are bundled into the final app (bloating binary size and web load times), and on some platforms the entire file is loaded into memory (e.g., iOS `AVAudioPlayer`). The current placeholder sounds are all under 100 KB — plenty of room before hitting that soft ceiling.

#### Where the code lives (line numbers in `lib/main.dart`)

All paths below are current as of the latest edit. Line numbers are annotations only — search for the `AssetSource(...)` string or the method name first.

**To swap an audio file, edit the `AssetSource('audio/….wav')` string** inside each method:

| Sound | Method (where the asset string lives) | Asset path |
|-------|---------------------------------------|------------|
| Dig | `playDigSound()` — **line 74** | `assets/audio/dig.wav` |
| Flag | `playFlagSound()` — **line 85** | `assets/audio/flag.wav` |
| Win jingle | `playWinSound()` — **line 96** | `assets/audio/win.wav` |
| Defeat jingle | `playDefeatSound()` — **line 108** | `assets/audio/defeat.wav` |

**The two `AudioPlayer` instances** (defeat vs. one-shot SFX players):

- `_sfxPlayer` — **line 55**
- `_defeatPlayer` — **line 59**

**Where each sound is triggered** (call sites):

| Event | Call site (line) |
|-------|------------------|
| Defeat jingle on mine hit | `playDefeatSound()` — **line 492** |
| Dig on successful reveal | `playDigSound()` — **line 498** |
| Win jingle on board clear | `playWinSound()` — **line 503** |
| Flag placed | `playFlagSound()` — **line 550** |
| SFX volume slider | `updateSfxVolume()` — **line 226** |

## Platforms

The app includes standard Flutter platform folders for:

- Android (`android/`)
- iOS (`ios/`)
- Web (`web/`)
- Windows (`windows/`)
- Linux (`linux/`)
- macOS (`macos/`)