# deskloop

```
   Deskloop

    ╔╦╗╔═╗╔═╗╦╔═╦  ╔═╗╔═╗╔═╗
     ║║║╣ ╚═╗╠╩╗║  ║ ║║ ║╠═╝
    ═╩╝╚═╝╚═╝╩ ╩╩═╝╚═╝╚═╝╩

  │ A minimal, zero-dependency live video wallpaper engine for macOS.
  │ Native by design: hardware accelerated, multi-display, and automatically
  │ pauses playback the moment your desktop is covered.
```

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-black.svg)](https://apple.com)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

---

## Vision

Most live wallpaper utilities for macOS are either 100MB+ Electron apps, require running background game clients like Steam, or murder MacBook battery life by continuously decoding 4K frames even when you are working inside full-screen IDEs or browser windows.

`deskloop` is built on one simple premise: a native, single-binary CLI tool that loops any video across your screens behind desktop icons, and pauses decoding the moment you're not looking at it.

---

## Features

- **Zero Dependencies**: Pure Swift using native `AppKit` and `AVFoundation`. Compiles in seconds to a ~400KB universal binary with no external packages.
- **Hardware Accelerated**: Decodes `.mp4`, `.mov`, and `.m4v` directly on Apple Silicon and Intel media engines. Audio is permanently muted.
- **Occlusion Auto-Pause**: Automatically detects when application windows cover the desktop and pauses the video decoder, dropping CPU/GPU usage to 0.0%.
- **Multi-Monitor & Spaces**: Automatically creates seamless borderless playback windows across every connected monitor and macOS virtual desktop (Space).
- **Display Sleep & Low Power Friendly**: Halts playback during display sleep, system sleep, or when macOS enters Low Power Mode.
- **Non-Destructive**: Runs at `kCGDesktopWindowLevel` without overwriting your system wallpaper settings. When stopped, your original wallpaper instantly reappears.
- **Scriptable**: Includes `--daemon` background execution and `--json` status output for scripts, window managers, and automated workflows.

---

## Installation

### Homebrew (Recommended)

```bash
brew tap bobinx/deskloop https://github.com/bobinx/deskloop
brew install deskloop
```

Installs the precompiled universal macOS binary (Apple Silicon and Intel).

### Build from Source

```bash
git clone https://github.com/bobinx/deskloop.git
cd deskloop
make install
```

`make install` places the binary in `/usr/local/bin` by default. To install elsewhere:

```bash
make install PREFIX="$HOME/.local"
```

---

## Usage

### 1. Loop a local video

Run in the background across all connected displays:

```bash
deskloop run ~/Movies/loop.mp4 --daemon
# or simply:
deskloop ~/Movies/loop.mp4 --daemon
```

To run in the foreground (stops when you press `Ctrl+C`):

```bash
deskloop run ~/Movies/loop.mp4
```

### 2. Stream a video URL

Direct HTTP or HTTPS video streams can be played directly:

```bash
deskloop run "https://example.com/aurora.mp4" --daemon
```

### 3. Check status

Inspect the active video, process ID, uptime, and connected displays:

```bash
deskloop status
```

Machine-readable JSON output for scripting:

```bash
deskloop status --json
```

### 4. Stop playback

Stop the running wallpaper engine and instantly restore your default desktop wallpaper:

```bash
deskloop stop
```

---

## Power Safeguards

Live wallpapers shouldn't drain your battery. `deskloop` enforces four native safeguards:

1. **Occlusion Detection**: When your desktop is hidden beneath other application windows, `AVQueuePlayer` pauses immediately. Decoding resumes when you reveal the desktop or swipe to an empty Space.
2. **Display Sleep Compliance**: `preventsDisplaySleepDuringVideoPlayback` is strictly set to `false`. Your displays sleep on schedule according to your Energy Saver settings.
3. **Sleep Notification Hooks**: Registers system and workspace sleep notifications to halt playback before the machine sleeps.
4. **Low Power Mode Awareness**: Watches `NSProcessInfoPowerStateDidChange` and freezes playback on the current frame while battery saver is active.

---

## Contributing

Contributions and bug reports are welcome. Please open an issue to discuss proposed changes before submitting a pull request.

`deskloop` strictly follows the Unix philosophy: do one thing and do it exceptionally well. It must remain a lightweight, zero-dependency, single-purpose CLI live wallpaper engine.

## License

[MIT](LICENSE) © [Bobin](https://github.com/bobinx)
