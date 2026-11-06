# Agent Guidelines (AGENTS.md)

This file provides context and operational guidelines for AI coding assistants and autonomous agents working on this codebase.

---

## 1. Project Overview

`deskloop` is a lightweight, zero-dependency, native Swift command-line live wallpaper engine for macOS 13.0+. It renders looping video on desktop windows behind macOS system UI, with playback suspended during occlusion, sleep, and Low Power Mode.

Key architectural characteristics:
- **Zero Third-Party Packages**: Strictly uses Apple native frameworks (`AppKit`, `AVFoundation`, `CoreGraphics`).
- **Core Library Separation**: Core orchestration lives in `DeskloopCore`, the CLI entrypoint in `Sources/deskloop/main.swift`.
- **Test-First Reliability**: All engine state, models, and power suspension reasons are tested via `Tests/DeskloopTests/`.

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

3. **Screen Sharing Compatibility**:
   - Every desktop window sets `window.sharingType = .none`.
   - Preserve this setting for legacy sharing behavior. Modern capture APIs can still capture the wallpaper; describe it as a compatibility setting rather than a privacy guarantee.

4. **Window Level & Behavior**:
   - Window level must be `kCGDesktopWindowLevel`.
   - Collection behavior must include `[.canJoinAllSpaces, .stationary, .ignoresCycle]`.

5. **Concurrency Safety**:
   - All classes exposed across async boundaries must conform to `Sendable`.
   - Avoid `@unchecked Sendable` unless interfacing with legacy non-sendable Apple SDK types where thread safety is manually guaranteed.

---

## 3. Build & Test Commands

Run `make verify` before declaring code changes complete. It runs unit tests, debug/release builds, and offline CLI contract checks:

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
```

---

## 4. Coding Standards

- **Error Handling**: Bubble errors to `main.swift` with descriptive messages. Never swallow errors with empty `catch {}`.
- **Formatting**: Preserve existing indentation (4 spaces) and naming conventions.
- **Purity**: Avoid global mutable state. Keep power state transitions inside `WallpaperEngine`.

---

## 5. Navigation and Contribution Workflow

- CLI syntax and options: `Sources/deskloop/CLICommand.swift`.
- Help text: `Sources/deskloop/CLIHelp.swift`. Update it when command behavior changes.
- Command execution and output: `Sources/deskloop/main.swift`.
- Process identity, startup acknowledgement, and engine lease: `Sources/deskloop/EngineProcessController.swift`.
- Offline interface checks: `Scripts/verify-cli.py`.

For PRs, follow `CONTRIBUTING.md`. Manual playback checks apply to playback, power, privacy, and display changes; docs-only changes do not require them. Keep desktop-changing tests out of `make verify`. Use `DESKLOOP_HOME` for isolated CLI state in tests.
