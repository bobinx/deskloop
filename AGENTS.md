# Agent Guidelines (AGENTS.md)

This file provides context and operational guidelines for AI coding assistants and autonomous agents working on this codebase.

---

## 1. Project Overview

`deskloop` is a lightweight, zero-dependency, native Swift command-line live wallpaper engine for macOS 13.0+. It renders 4K looping video on desktop windows behind macOS system UI without draining MacBook battery.

Key architectural characteristics:
- **Zero Third-Party Packages**: Strictly uses Apple native frameworks (`AppKit`, `AVFoundation`, `CoreGraphics`, `VideoToolbox`).
- **Core Library Separation**: Core orchestration lives in `DeskloopCore`, the CLI entrypoint in `Sources/deskloop/main.swift`.
- **Test-First Reliability**: All models, utilities, and protocols are tested via `Tests/DeskloopTests/`.

---

## 2. Invariants (Never Break These)

When making code changes, agents must preserve the following power management and system safety invariants:

1. **Occlusion Auto-Pause**:
   - `WallpaperEngine` must register `NSWindow.didChangeOcclusionStateNotification` per screen window.
   - When windows are occluded, decoding and playback must pause (`entry.player.pause()`).
   - Observers must be tracked on the screen entry and removed during window teardown to prevent leaks on display plug/unplug.

2. **Display Sleep Compliance**:
   - `queuePlayer.preventsDisplaySleepDuringVideoPlayback` must remain `false`. Never set this to `true`, or MacBooks will stay awake indefinitely.
   - Observers for `screensDidSleepNotification` and `willSleepNotification` must halt playback immediately.

3. **Screen Sharing Privacy**:
   - Every desktop window must set `window.sharingType = .none`.
   - Never remove this; omitting it causes macOS WindowManager to trigger screen-recording permission dialogs and captures wallpaper pixels during Zoom/Teams calls.

4. **Window Level & Behavior**:
   - Window level must be `kCGDesktopWindowLevel`.
   - Collection behavior must include `[.canJoinAllSpaces, .stationary, .ignoresCycle]`.

5. **Concurrency Safety**:
   - All classes exposed across async boundaries must conform to `Sendable`.
   - Avoid `@unchecked Sendable` unless interfacing with legacy non-sendable Apple SDK types where thread safety is manually guaranteed.

---

## 3. Build & Test Commands

Run `make verify` before declaring code changes complete. It runs the following builds and tests plus offline CLI/MCP contract checks:

```bash
# Run unit tests
swift test

# Build debug
swift build

# Build release
swift build -c release

# Check CLI flags
.build/release/deskloop --help
.build/release/deskloop --version
.build/release/deskloop sources
```

---

## 4. How to Add a New Wallpaper Source

All sources conform to `WallpaperSource` in `Sources/DeskloopCore/WallpaperSource.swift`:

```swift
public protocol WallpaperSource: Sendable {
    var name: String { get }
    var description: String { get }

    func fetchFeatured(limit: Int) async throws -> [WallpaperItem]
    func search(query: String) async throws -> [WallpaperItem]
    func resolve(id: String) async throws -> WallpaperItem?
}
```

Rules for new sources:
- Videos must be directly playable `.mp4` or `.mov` streams or local files.
- Never hardcode proprietary API keys, leaked tokens, or fragile web-scrapers.
- Return high-quality, seamless loops suitable for desktop backgrounds.
- Register new sources in `Sources/deskloop/main.swift` under `getRegisteredSources()`.

---

## 5. Coding Standards

- **Error Handling**: Bubble errors to `main.swift` with descriptive messages. Never swallow errors with empty `catch {}`.
- **Formatting**: Preserve existing indentation (4 spaces) and naming conventions.
- **Purity**: Avoid global mutable state. Keep power state transitions inside `WallpaperEngine`.

## 6. Navigation and contribution workflow

- CLI syntax and options: `Sources/deskloop/CLICommand.swift`.
- Help text: `Sources/deskloop/CLIHelp.swift`. Update it when command behavior changes.
- Command execution and output: `Sources/deskloop/main.swift`.
- MCP transport and tool contracts: `Sources/deskloop/MCPServer.swift`.
- Process identity, startup acknowledgement, and engine lease: `Sources/deskloop/EngineProcessController.swift`.
- Offline interface checks: `Scripts/verify-cli.py`.

For agent usage or MCP integration, read `docs/agents.md`.
For PRs, follow `CONTRIBUTING.md` and the PR template. Record unperformed checks
explicitly. Manual playback checks apply to playback, power, privacy, and display
changes; docs-only changes do not require them. Keep desktop-changing tests out
of `make verify`. Use `DESKLOOP_HOME` for isolated CLI state in tests.
