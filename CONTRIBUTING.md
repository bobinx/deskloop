# Contributing to deskloop

Thank you for your interest in contributing to deskloop.

## Development setup

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

The repository is structured into two targets:

- `Sources/DeskloopCore/`: Core library containing playback engine (`WallpaperEngine`), display management, power suspension hooks (`PlaybackSuspensionReasons`), and paths (`DeskloopPaths`).
- `Sources/deskloop/`: Thin command-line interface executable that handles argument parsing, terminal output, and process daemonization.
- `Tests/DeskloopTests/`: Unit tests for engine state serialization, sandbox paths, and power suspension states.

## Human and AI-authored contributions

Both human-crafted and AI-assisted contributions are welcome, provided they meet our quality bar:

- **Verification over self-reporting**: Run `make verify` for code changes. For playback, power, privacy, or display changes, also test the affected behavior in a graphical macOS session.
- **Maintain power invariants**: Never disable occlusion detection or sleep tracking. `preventsDisplaySleepDuringVideoPlayback` must remain `false`.
- **Zero third-party dependencies**: Do not introduce CocoaPods, Carthage, or third-party SwiftPM dependencies. Keep the binary lightweight and self-contained.
- **Clean diffs**: Avoid stylistic churn, unsolicited reformatting, or extraneous comments. Keep changes focused.

## Automated checks

CI runs secret scanning (`gitleaks`), unit tests, debug/release builds, and CLI contract tests automatically on every pull request and push to `main`.

## Pull request checklist

- [ ] `make verify` passes.
- [ ] Added or updated unit tests for new logic.
- [ ] Documentation updated in `README.md` if CLI flags or options changed.

## Review and compatibility

Please open an issue before proposing architectural changes.
Keep pull requests focused and explain the macOS versions and display configurations used for manual testing. We support macOS 13 and newer; changes to playback, sleep, or display handling need manual verification.
