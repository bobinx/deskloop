# Contributing

## Setup

### Prerequisites

- macOS 13.0 or later
- Swift 5.9 or later (included with Xcode 15+ or Command Line Tools)
- Python 3 for offline CLI contract checks

### Building and testing

```bash
# Clone the repository
git clone https://github.com/bobinx/deskloop.git
cd deskloop

# Run unit tests, debug/release builds, and offline CLI checks
make verify
.build/release/deskloop --help
.build/release/deskloop --version
```

## Project architecture

- `Sources/DeskloopCore/`: Core library containing the playback engine (`WallpaperEngine`), display management, power suspension hooks (`PlaybackSuspensionReasons`), and paths (`DeskloopPaths`).
- `Sources/deskloop/`: Thin CLI executable handling argument parsing, terminal output, and process daemonization.
- `Tests/DeskloopTests/`: Unit tests for engine state serialization, sandbox paths, and power suspension states.

## Guidelines

- **Verification.** Run `make verify` for code changes. For playback, power, privacy, or display changes, test in a real graphical macOS session.
- **Power invariants.** Never disable occlusion detection or sleep tracking. `preventsDisplaySleepDuringVideoPlayback` must stay `false`.
- **No third-party packages.** Use native Apple frameworks only. Keep the binary self-contained without adding package dependencies.
- **Clean diffs.** Avoid stylistic churn or unsolicited reformatting. Keep changes focused.

## Automated checks

CI runs secret scanning (`gitleaks`), unit tests, debug and release builds, and CLI contract tests automatically on pull requests and pushes to `main`.

## Pull request checklist

- [ ] `make verify` passes.
- [ ] Added or updated unit tests for new logic.
- [ ] Documentation updated in `README.md` if CLI flags or options changed.

## Review and compatibility

Open an issue before proposing architectural changes. Explain the macOS versions and display setups used for testing. Changes to playback, sleep, or display handling require manual verification on hardware.
