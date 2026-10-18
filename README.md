# deskloop

A lightweight command line live wallpaper engine for macOS with multi-monitor support, occlusion-based power saving, and official Apple 4K aerial loops.

## Requirements

- macOS 13.0 (Ventura) or newer
- Swift 5.9 or newer (for building from source)

## Installation

### Option 1: Via Homebrew (Recommended once tap is published)

```bash
brew tap your-username/deskloop
brew install deskloop
```

### Option 2: Quick install (1-line script)

```bash
curl -fsSL https://raw.githubusercontent.com/your-username/deskloop/main/install.sh | bash
```

### Option 3: Manual build from source

```bash
git clone https://github.com/your-username/deskloop.git
cd deskloop
make install
```

Or run directly without installing system-wide:

```bash
swift build -c release
./deskloop --help
```

## Supported sources

deskloop focuses on two reliable video sources:

1. **`apple` (default)**: 114 official Apple 4K Aerial and screensaver loops (drone, satellite, and underwater scenes) streamed and cached directly from Apple's CDN (`sylvan.apple.com`). Requires no API key.
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

- **Window occlusion auto-pause**: Video decoding halts when open application windows cover the desktop, dropping CPU and GPU usage to zero. Playback resumes automatically when the desktop becomes visible.
- **Display sleep friendly**: Configured so macOS screens sleep normally according to your Energy Saver settings.
- **Sleep tracking**: Video decoding pauses during display or system sleep.
- **Low Power Mode awareness**: Automatically suspends playback when macOS enters battery saver mode.
- **Hardware accelerated**: Uses VideoToolbox to decode directly into Metal surfaces without CPU buffer copying. Audio playback is muted to avoid CoreAudio wakeups.

## License

MIT
