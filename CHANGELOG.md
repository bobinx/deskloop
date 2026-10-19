# Changelog

## [1.2.0] - 2026-10-20

### Added

- `deskloop apply <target> --daemon --json` returns the acknowledged engine PID and video path.
- Command-specific help through `deskloop <command> --help` and `deskloop help <command>`.
- `DESKLOOP_HOME` overrides the directory for process state, logs, cached videos, the Apple catalog, and extracted static frames.
- An agent workflow guide covering discovery, exact-ID selection, applying, verification, and error recovery.
- `make verify` runs unit tests, debug and release builds, and offline CLI/MCP contract checks with isolated state. CI runs the same checks.
- A pull request template and updated contributor guidance distinguish automated checks from manual playback verification.

### Fixed

- CLI and MCP background apply wait up to five seconds for the child engine to acknowledge startup instead of reporting success immediately after spawning it. Startup failures, including an engine lease conflict, now return errors.
- MCP search and featured tools validate limits before fetching data. Negative, zero, fractional, boolean, string, and values above 100 return tool errors instead of reaching unsafe collection operations. The default remains 10.
- MCP status reports unreadable or corrupt state as an error instead of claiming playback is stopped.
- A stop timeout now returns a CLI failure or MCP tool error. Stopping an already stopped engine remains a successful no-op.
- Malformed JSON received by the MCP server returns a parse error instead of being silently discarded.
- Background child processes use null stdin, keeping MCP input separate from playback.
- Help output is plain text without ANSI escapes and documents defaults, aliases, JSON support, data locations, and exit codes. Unverified resource-usage claims were removed from help.

### Compatibility

- JSON-mode failures now write an `error` object containing `domain`, `code`, and `message` to stdout and exit with code 1. Human-readable top-level errors go to stderr.
- Commands that do not support JSON reject `--json` instead of silently ignoring it. Foreground apply requires omission of `--json`; use `--daemon --json` for automation.
- Apply acknowledges engine startup, not successful media decoding. Status reports process liveness, not playback progress.
- Existing playback, power-management, privacy, and window configuration are unchanged. Live playback and sleep/display behavior were not manually verified for this release.

[1.2.0]: https://github.com/bobinx/deskloop/compare/v1.1.0...v1.2.0
