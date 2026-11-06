# Agent guidelines

Guidelines for autonomous agents and tools working on this codebase.

---

## 1. Project overview

`deskloop` is a lightweight, zero-dependency command-line live wallpaper engine for macOS 13.0+. It renders looping video on desktop windows behind macOS system UI, and pauses playback during occlusion, sleep, and Low Power Mode.

- Zero third-party packages. Uses native Apple frameworks (`AppKit`, `AVFoundation`, `CoreGraphics`).
- Core orchestration lives in `DeskloopCore`, CLI entrypoint in `Sources/deskloop/main.swift`.
- Engine state, models, and power suspension reasons are tested in `Tests/DeskloopTests/`.

---

## 2. Invariants

Preserve these power management and safety invariants when modifying code:

1. **Occlusion auto-pause.** Register `NSWindow.didChangeOcclusionStateNotification` per screen window. Pause decoding and playback when windows are occluded (`entry.player.pause()`). Remove observers during window teardown to prevent leaks when displays change.
2. **Display sleep compliance.** `queuePlayer.preventsDisplaySleepDuringVideoPlayback` must remain `false`. Never set this to `true`. Observers for `screensDidSleepNotification` and `willSleepNotification` must halt playback immediately.
3. **Screen sharing compatibility.** Desktop windows set `window.sharingType = .none`. Describe this as a legacy compatibility setting, not a privacy guarantee.
4. **Window level and behavior.** Window level must be `kCGDesktopWindowLevel`. Collection behavior must include `[.canJoinAllSpaces, .stationary, .ignoresCycle]`.
5. **Concurrency safety.** Types exposed across async boundaries must conform to `Sendable`. Avoid `@unchecked Sendable`.

---

## 3. Build and test commands

Run `make verify` before declaring changes complete. It runs unit tests, debug and release builds, and offline CLI contract checks:

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

## 4. Coding standards

- **Error handling.** Bubble errors to `main.swift` with descriptive messages. Never swallow errors with empty `catch {}`.
- **Formatting.** Use 4 spaces for indentation. Match existing naming conventions.
- **Purity.** Avoid global mutable state. Keep power state transitions inside `WallpaperEngine`.

---

## 5. Navigation and workflow

- CLI syntax and options: `Sources/deskloop/CLICommand.swift`.
- Help text: `Sources/deskloop/CLIHelp.swift`. Update it when command behavior changes.
- Command execution: `Sources/deskloop/main.swift`.
- Process identity and engine lease: `Sources/deskloop/EngineProcessController.swift`.
- Offline interface checks: `Scripts/verify-cli.py`.

For PRs, follow `CONTRIBUTING.md`. Keep desktop-changing tests out of `make verify`. Use `DESKLOOP_HOME` for isolated CLI state in tests.
