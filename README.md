# deskloop

```
   Deskloop

    ╔╦╗╔═╗╔═╗╦╔═╦  ╔═╗╔═╗╔═╗
     ║║║╣ ╚═╗╠╩╗║  ║ ║║ ║╠═╝
    ═╩╝╚═╝╚═╝╩ ╩╩═╝╚═╝╚═╝╩

  │ Minimal, zero-dependency live video wallpaper for macOS.
  │ Native Swift, hardware accelerated, and automatically pauses
  │ the moment your desktop is covered.
```

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-black.svg)](https://apple.com)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

---

## Get Started

### 1. Install

Using Homebrew:

```bash
brew tap bobinx/deskloop https://github.com/bobinx/deskloop
brew install deskloop
```

Or build from source in seconds (no external dependencies):

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

## Why I Built This

I wanted looping video wallpapers on my Mac, but the existing options bugged me:
- Heavy GUI apps that take 100MB+ of memory just to loop an MP4.
- Running Steam in the background just for Wallpaper Engine.
- Battery drain: most tools keep decoding video at full tilt even when you're working inside a full-screen browser or code editor.

`deskloop` is a lightweight native CLI utility that solves this:
1. **Zero CPU when covered**: macOS notifies `deskloop` when application windows obscure the desktop, and the video decoder pauses immediately.
2. **Zero dependencies**: Written purely in Swift with native AppKit and AVFoundation. Compiles to a single ~400KB binary.
3. **Safe**: Sits behind your desktop icons (`kCGDesktopWindowLevel`) without modifying your system wallpaper settings. When you stop it, your desktop goes right back to how you left it.
4. **Sleep & battery friendly**: Never blocks display sleep, pauses when screens sleep, and freezes on the current frame during Low Power Mode.

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

Contributions and bug reports are welcome. Please open an issue to discuss proposed changes before opening a pull request.

`deskloop` strictly follows the Unix philosophy: do one thing and do it well. It must stay lightweight, zero-dependency, and battery-friendly.

## License

[MIT](LICENSE) © [Bobin](https://github.com/bobinx)
