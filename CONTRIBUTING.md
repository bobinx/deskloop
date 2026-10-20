# Contributing to deskloop

Thank you for your interest in contributing to deskloop.

## Development setup

### Prerequisites

- macOS 13.0 or later
- Swift 5.9 or later (included with Xcode 15+ or Command Line Tools)
- Python 3 for CLI/MCP contract checks
- [pre-commit](https://pre-commit.com/) and [gitleaks](https://github.com/gitleaks/gitleaks) for secret scanning (`brew install pre-commit gitleaks`)

### Building and testing

```bash
# Clone the repository
git clone https://github.com/bobinx/deskloop.git
cd deskloop

# Run unit tests, debug/release builds, and offline CLI/MCP checks
# (this also activates pre-commit and pre-push secret scanning hooks)
make verify
.build/release/deskloop --help
.build/release/deskloop --version
.build/release/deskloop sources
```

## Project architecture

The repository is structured into two targets:

- `Sources/DeskloopCore/`: Core library containing playback engine (`WallpaperEngine`), download delegate (`FileDownloader`), static keyframe extraction (`StaticWallpaperService`), and source protocols (`WallpaperSource`).
- `Sources/deskloop/`: Thin command-line interface executable that handles argument parsing, terminal output, and process daemonization.
- `Tests/DeskloopTests/`: Unit tests for utilities, serialization, and source protocols.

## Adding a new wallpaper source

All wallpaper providers implement the `WallpaperSource` protocol:

```swift
public protocol WallpaperSource: Sendable {
    var name: String { get }
    var description: String { get }

    func fetchFeatured(limit: Int) async throws -> [WallpaperItem]
    func search(query: String) async throws -> [WallpaperItem]
    func resolve(id: String) async throws -> WallpaperItem?
}
```

New sources should:
1. Stream or cache playable `.mp4` or `.mov` loops directly.
2. Avoid fragile third-party scrapers or unauthenticated endpoints that break without notice.
3. Be non-blocking and concurrency-safe (`Sendable`).
4. Register the new source in `Sources/deskloop/main.swift` under `getRegisteredSources()`.

## Human and AI-authored contributions

Both human-crafted and AI-assisted contributions are welcome, provided they meet our quality bar:

- **Verification over self-reporting**: Run `make verify` for code changes. For playback, power, privacy, or display changes, also test the affected behavior in a graphical macOS session. Record checks you cannot run and why. Documentation-only changes need link and command review.
- **Maintain power invariants**: Never disable occlusion detection or sleep tracking. `preventsDisplaySleepDuringVideoPlayback` must remain `false`.
- **Zero third-party dependencies**: Do not introduce CocoaPods, Carthage, or third-party SwiftPM dependencies. Keep the binary lightweight and self-contained.
- **Clean diffs**: Avoid stylistic churn, unsolicited reformatting, or AI-tell commentary. Keep changes focused.

## Secret scanning

Secrets, API keys, and credentials are blocked at three levels using
[pre-commit](https://pre-commit.com/) and [gitleaks](https://github.com/gitleaks/gitleaks):

1. **Pre-commit hook** — gitleaks scans staged changes before each commit.
2. **Pre-push hook** — gitleaks scans changes before each push.
3. **CI** — runs the official gitleaks GitHub Action on every PR and push to `main`.

Hooks activate automatically the first time you run `make build`, `make test`,
or `make verify`. You can also run `pre-commit install && pre-commit install --hook-type pre-push` manually.

Run `gitleaks detect --verbose` to scan the full repo at any time.

## Pull request checklist

- [ ] `make verify` passes (includes secret scan), or environment limitations are recorded.
- [ ] Added or updated unit tests for new logic.
- [ ] Documentation updated in `README.md` if CLI flags or options changed.

## Review and compatibility

Please open an issue before starting a large feature or a new wallpaper provider.
Keep pull requests focused and explain the macOS versions and display configurations
used for manual testing. We support macOS 13 and newer; changes to playback, sleep,
screen sharing, or display handling need manual verification on the configurations
they affect.

Do not add media assets from providers unless their redistribution terms permit it.

## Manual engine verification

For changes to the engine or process lifecycle, use a local playable video and
record the result of applying, checking status, stopping, and applying again.
For display or power changes, also check the affected cases: covering the desktop,
sleep and wake, Low Power Mode, display connection changes, and Spaces.
For privacy changes, verify wallpaper capture behavior with the supported macOS
versions. Automated checks do not establish these OS behaviors.

Small bug fixes, tests, and documentation improvements can go directly to a PR.
Use the PR template to describe observable behavior and verification. Include a
reproduction command for bugs. Changes to CLI or MCP contracts need offline
checks in `Scripts/verify-cli.py` and updated help or agent documentation.
