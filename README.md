# deskloop

```
   Deskloop

    ╔╦╗╔═╗╔═╗╦╔═╦  ╔═╗╔═╗╔═╗
     ║║║╣ ╚═╗╠╩╗║  ║ ║║ ║╠═╝
    ═╩╝╚═╝╚═╝╩ ╩╩═╝╚═╝╚═╝╩

  │ Live video wallpaper for macOS.
  │ Native Swift, hardware accelerated, and automatically pauses
  │ the moment your desktop is covered.
```

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-black.svg)](https://apple.com)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

---

## Getting started

### 1. Install

Using Homebrew:

```bash
brew tap bobinx/deskloop https://github.com/bobinx/deskloop
brew install deskloop
```

Or build from source in seconds (no external packages needed):

```bash
git clone https://github.com/bobinx/deskloop.git
cd deskloop && make install
```

### 2. Run a wallpaper

Point it to any `.mp4`, `.mov`, or `.m4v` file:

```bash
# Run in the background across all your screens
deskloop ~/Movies/loop.mp4 --daemon

# Check status
deskloop status

# Stop and restore your original wallpaper
deskloop stop
```

You can also pass a direct video URL:

```bash
deskloop "https://example.com/loop.mp4" --daemon
```

---

## Why I built this

I wanted looping video wallpapers on my Mac, but the existing tools bugged me:
- Heavy GUI apps that burn 100MB+ of memory to loop an MP4.
- Running Steam in the background just for Wallpaper Engine.
- Battery drain. Most tools keep decoding frames at full speed even when you are buried in a full-screen editor.

deskloop fixes that by doing less:
1. **Pauses when covered.** macOS notifies deskloop when windows cover the desktop, and the video decoder pauses immediately to save CPU and battery.
2. **Self-contained.** Built directly on AppKit and AVFoundation. Compiles in seconds to a single ~400KB binary with no external packages.
3. **Safe.** Runs behind desktop icons (`kCGDesktopWindowLevel`) without touching system wallpaper settings. Stop it and your desktop returns to how you left it.
4. **Sleep friendly.** Never blocks display sleep, pauses when screens sleep, and freezes on the current frame during Low Power Mode.

---

## Commands

| Command | Description |
| :--- | :--- |
| `deskloop <file\|url> [--daemon]` | Play a video on all connected monitors |
| `deskloop run <file\|url> [--daemon]` | Explicit run syntax |
| `deskloop status [--json]` | Show active video, process ID, uptime, and displays |
| `deskloop stop [--json]` | Stop playback and restore original wallpaper |
| `deskloop --help` | Show usage options |
| `deskloop --version` | Show installed version |

---

## Contributing

Contributions and bug reports are welcome. Open an issue to discuss proposed changes before opening a pull request.

deskloop follows the Unix philosophy: do one thing and do it well. It must stay small, battery-friendly, and focused on its core job.

## License

[MIT](LICENSE) © [Bobin](https://github.com/bobinx)
