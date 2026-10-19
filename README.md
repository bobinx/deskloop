# deskloop

A lightweight command line live wallpaper engine for macOS with multi-monitor support, occlusion-based power saving, and official Apple 4K aerial loops.

## Requirements

- macOS 13.0 (Ventura) or newer
- Swift 5.9 or newer (for building from source)

## Installation

### Homebrew

```bash
brew tap bobinx/deskloop https://github.com/bobinx/deskloop
brew install bobinx/deskloop/deskloop
```

Homebrew builds deskloop from source, so Xcode 15 or newer is required.

### Build from source

```bash
git clone <repository-url>
cd deskloop
make install
```

Or run directly without installing system-wide:

```bash
swift build -c release
.build/release/deskloop --help
```

`make install` installs to `/usr/local/bin` by default. Choose another location with
`make install PREFIX="$HOME/.local"` and ensure that directory is on your `PATH`.

## Supported sources

deskloop focuses on two reliable video sources:

1. **`apple` (default)**: Apple Aerial loops (drone, satellite, and underwater scenes) streamed and cached directly from Apple's CDN (`sylvan.apple.com`). Requires no API key.
2. **`local`**: Any local video file (`.mp4`, `.mov`, `.m4v`) or directory on your Mac.

To use external videos (from YouTube, Wallpaper Engine, reddit, or stock sites), download the `.mp4` file and pass its path or URL directly to `deskloop apply`.

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

## Power and resource management

Video playback consumes battery if unmanaged. deskloop implements five power safeguards:

- **Window occlusion auto-pause**: Playback pauses when the desktop window is occluded and resumes when it becomes visible.
- **Display sleep friendly**: Configured so macOS screens sleep normally according to your Energy Saver settings.
- **Sleep tracking**: Playback pauses during display or system sleep.
- **Low Power Mode awareness**: Automatically suspends playback when macOS enters battery saver mode.
- **Hardware accelerated playback**: AVFoundation uses macOS's supported video playback path. Audio is muted.

## Data, network, and privacy

Deskloop stores its state, logs, downloaded videos, and extracted static frames in
`~/.deskloop/`. `cache clear` removes downloaded videos but keeps static wallpaper
frames. The `apple` source requests its catalog and videos from Apple's CDN; direct
URLs are contacted only when you apply them. The live wallpaper windows opt out of
window sharing so the wallpaper is not offered to screen-capture clients.

## Current limits

- The same video is applied to every connected display.
- Live wallpaper playback lasts until `deskloop stop`, a signal, or process exit;
  Deskloop does not currently install a login item or persistent background service.
- Direct URLs must point to a video stream that AVFoundation can play.
- Apple-provided media is not redistributed by this project. Check the source's
  applicable terms before sharing downloaded files.

## License

MIT
