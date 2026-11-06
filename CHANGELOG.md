# Changelog

All notable changes to `deskloop` will be documented in this file.

## [Unreleased]

### Added
- Independent bitmask suspension states for display sleep, system sleep, and Low Power Mode.
- Video playback failure diagnostics logged to stderr and daemon log.
- Shorthand execution syntax (`deskloop <path|url> [--daemon]`).

### Fixed
- Occlusion auto-pause state transitions cleanly synchronize with window visibility.
- Engine teardown cleanly resets internal video state on stop.
- Process identity verification accurately prevents stale PID reuse.

## [1.2.0] - 2026-10-20

### Added
- Background daemon execution via `--daemon` with child PID startup acknowledgment.
- Machine-readable `--json` output for process status and automation workflows.
- Command-specific help via `deskloop <command> --help`.
- Sandboxed directory override via `DESKLOOP_HOME`.

### Fixed
- Status detection accurately verifies process identity via PID and start time.
- Stop timeouts return descriptive error messages.
