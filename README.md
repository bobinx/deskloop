# deskloop

> **CLI live video wallpaper engine for macOS.** Loop any local video (`.mp4`, `.mov`) or official Apple 4K Aerial across all monitors with hardware acceleration and zero battery drain when occluded or sleeping. Built with zero dependencies, native Model Context Protocol (MCP) support, and machine-readable JSON mode for AI agents.

## Requirements

- macOS 13.0 (Ventura) or newer
- Swift 5.9 or newer (for building from source)

## Installation

### Homebrew (Recommended)

```bash
brew tap bobinx/deskloop https://github.com/bobinx/deskloop
brew install deskloop
```

Installs the precompiled universal macOS binary (Apple Silicon and Intel). No Xcode or local compilation required.

### Build from source

```bash
git clone https://github.com/bobinx/deskloop.git
cd deskloop
make install
```

Or run directly without installing system-wide:

```bash
swift build -c release
.build/release/deskloop --help
```

`make install` installs to `/usr/local/bin` by default. Choose another location with `make install PREFIX="$HOME/.local"` and ensure that directory is on your `PATH`.

---

## AI Agent & MCP Integration

`deskloop` includes a built-in stdio [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server. AI assistants (Claude Desktop, Cursor, Antigravity, etc.) can discover and manage live wallpapers as first-class tools.

### Connect to Claude Desktop or Cursor
Add `deskloop` to your `claude_desktop_config.json` or Cursor MCP settings:

```json
{
  "mcpServers": {
    "deskloop": {
      "command": "deskloop",
      "args": ["mcp"]
    }
  }
}
```

### Available Tools:
- **`apply_wallpaper`**: Set a video path, direct URL, or Apple Aerial as the live looping wallpaper across all monitors.
- **`stop_wallpaper`**: Stop the running live wallpaper daemon.
- **`get_status`**: Get live wallpaper status, PID, active video path, and connected displays.
- **`search_wallpapers`**: Search Apple 4K Aerials by keyword or location.
- **`list_featured`**: List featured official Apple 4K Aerials.
- **`set_static_wallpaper`**: Set the first frame of a video as the system static desktop wallpaper.

### Machine-Readable JSON Mode
Every query and status command supports `--json` for seamless scripting and agent execution:

```bash
deskloop status --json
deskloop search "Greenland" --json
deskloop featured 10 --json
deskloop sources --json
deskloop cache list --json
```

---

## Supported sources

deskloop focuses on two reliable video sources:

1. **`apple` (default)**: Apple Aerial loops (drone, satellite, and underwater scenes) streamed and cached directly from Apple's CDN (`sylvan.apple.com`). Requires no API key.
2. **`local`**: Any local video file (`.mp4`, `.mov`, `.m4v`) or directory on your Mac.

To use external videos (from YouTube, Wallpaper Engine, reddit, or stock sites), download the `.mp4` file and pass its path or URL directly to `deskloop apply`.

---

## Usage

### Browse and search Apple 4K aerials

Browse featured 4K wallpapers:

```bash
deskloop featured 10
```

Search by location, keyword, or camera pass:

```bash
deskloop search "Greenland"
deskloop search "Hawaii"
deskloop search "Los Angeles"
```

### Apply a live wallpaper

Apply an Apple aerial in the background:

```bash
deskloop apply "Korea and Japan Night" --daemon
```

Apply a local video file:

```bash
deskloop apply ~/Movies/space.mp4 --daemon
```

Apply a direct video URL:

```bash
deskloop apply "https://example.com/loop.mp4" --daemon
```

Run in foreground (stops when you press `Ctrl+C`):

```bash
deskloop apply "Korea and Japan Night"
```

### Check status and stop

Check currently running wallpaper, process ID, uptime, and active displays:

```bash
deskloop status
```

Stop the running wallpaper engine:

```bash
deskloop stop
```

### Apply as permanent static wallpaper

Extract the first frame of any video and apply it as the system desktop wallpaper across all screens without keeping any process running:

```bash
deskloop set-static "Korea and Japan Night"
```

### Download a video

Save a 4K loop directly to a local file:

```bash
deskloop download "Korea and Japan Night" -o night.mp4
```

### Manage disk cache

List all cached videos and their disk space:

```bash
deskloop cache list
```

Delete cached videos to reclaim disk space:

```bash
deskloop cache clear
```

---

## Power and resource management

Video playback consumes battery if unmanaged. deskloop implements five power safeguards:

- **Window occlusion auto-pause**: Playback pauses when the desktop window is occluded and resumes when it becomes visible.
- **Display sleep friendly**: Configured so macOS screens sleep normally according to your Energy Saver settings.
- **Sleep tracking**: Playback pauses during display or system sleep.
- **Low Power Mode awareness**: Automatically suspends playback when macOS enters battery saver mode.
- **Hardware accelerated playback**: AVFoundation uses macOS's supported video playback path. Audio is muted.

---

## Data, network, and privacy

Deskloop stores its state, logs, downloaded videos, and extracted static frames in `~/.deskloop/`. `cache clear` removes downloaded videos but keeps static wallpaper frames. The `apple` source requests its catalog and videos from Apple's CDN; direct URLs are contacted only when you apply them. The live wallpaper windows opt out of window sharing so the wallpaper pixels are never captured during screen shares or recordings.

---

## Current limits

- The same video is applied to every connected display.
- Live wallpaper playback lasts until `deskloop stop`, a signal, or process exit; Deskloop does not currently install a login item or persistent background service.
- Direct URLs must point to a video stream that AVFoundation can play.
- Apple-provided media is not redistributed by this project. Check the source's applicable terms before sharing downloaded files.

## License

MIT
