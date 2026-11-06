# deskloop

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-black.svg)](https://apple.com)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

`deskloop` plays looping video wallpapers on macOS desktop windows from the command line.

It displays video behind desktop icons, pauses decoding when windows cover the screen, and suspends during display sleep or Low Power Mode.

---

## Installation

### Homebrew

```bash
brew tap bobinx/deskloop https://github.com/bobinx/deskloop
brew install deskloop
```

### From source

Requires Swift 5.9+ and macOS 13.0+:

```bash
git clone https://github.com/bobinx/deskloop.git
cd deskloop && make install
```

---

## Quick start

```bash
# Play a video in the background across all screens
deskloop ~/Movies/loop.mp4 --daemon

# Check status
deskloop status

# Stop playback
deskloop stop
```

Remote video URLs are also supported:

```bash
deskloop "https://example.com/loop.mp4" --daemon
```

---

## Behavior

- **Occlusion auto-pause:** macOS notifies deskloop when other windows cover the screen. Video decoding pauses immediately to avoid battery and CPU usage.
- **Power awareness:** Playback stops immediately during display sleep, system sleep, or Low Power Mode.
- **Non-destructive:** Windows are placed at `kCGDesktopWindowLevel` behind desktop icons. Stopping deskloop returns the desktop to your configured macOS wallpaper without altering system preferences.

---

## Commands

| Command | Description |
| :--- | :--- |
| `deskloop <file\|url> [--daemon]` | Play video on all connected monitors |
| `deskloop run <file\|url> [--daemon]` | Explicit run syntax |
| `deskloop status [--json]` | Show active video, process ID, uptime, and displays |
| `deskloop stop [--json]` | Stop playback and close wallpaper windows |
| `deskloop --help` | Show usage options |
| `deskloop --version` | Show installed version |

---

## Contributing

Open an issue to discuss proposed changes before submitting a pull request.

## License

[MIT](LICENSE) © [Bobin](https://github.com/bobinx)
