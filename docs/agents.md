# Use deskloop from an agent

Use deskloop to search Apple aerials, apply a downloaded video, or set a static
frame on macOS 13 or newer. Playback requires a logged-in graphical session.

## Apply and verify a wallpaper

1. Run `deskloop sources --json` to discover sources.
2. Run `deskloop search "Greenland" --json` or `deskloop featured 10 --json`.
3. Select an exact `id` from the returned objects. Names can match several items.
4. Run `deskloop status --json`. If an engine is running, run
   `deskloop stop --json` before changing its video.
5. Run `deskloop apply "<id>" --daemon --json`.
6. Run `deskloop status --json` and compare the returned PID with the apply result.

For a local video, use an absolute path in place of the ID. Direct HTTP or HTTPS
URLs must point to playable media. Applying a source item can download a large
video. Changing live or static wallpaper affects every display.

Apply success means the engine created its windows and recorded its process
identity. It does not confirm that AVFoundation decoded the video. Inspect the
wallpaper and `~/.deskloop/live.log` if playback fails. Status reports process
liveness, not playback progress or whether power management paused the video.

## Handle results and failures

JSON commands write one JSON value to stdout. Failures exit with code 1 and return
`{"error":{"domain":"...","code":1,"message":"..."}}`. Preserve the message
when reporting errors. Human-readable failures go to stderr. Success exits with
code 0. Stopping an already stopped engine succeeds as a no-op; inspect its
`success` field to distinguish a stopped process from a no-op.

JSON is supported by version, sources, featured, search, status, stop, cache, and
apply with `--daemon`. Other commands reject `--json`. Help is plain text.
Run `deskloop <command> --help` for syntax and defaults.

A failed launch is not safe to retry blindly. Check status and the log first.
Unreadable state returns an error instead of claiming the engine is stopped.

## Connect through MCP

Configure your MCP client with:

```json
{"mcpServers":{"deskloop":{"command":"deskloop","args":["mcp"]}}}
```

Use an absolute executable path if your client does not inherit your shell PATH.
The server uses newline-delimited JSON over stdio. Discover inputs with
`tools/list`. Tool results currently contain text and `isError`; inspect both.
Search and featured limits are integers from 1 to 100, with a default of 10.
Use `get_status`, `stop_wallpaper`, and `apply_wallpaper` in the same sequence as
the CLI workflow. Keep protocol stdout separate from diagnostics.

## Verify a contribution

Read [CONTRIBUTING.md](../CONTRIBUTING.md) for setup and manual verification.
Run `make verify` before submitting code. The Python 3 smoke checks use temporary
state, require no network, and do not change desktop wallpaper.

Set `DESKLOOP_HOME` to an absolute temporary directory when testing commands that
write state. The variable overrides the state, log, video cache, and Apple catalog
directory. It does not sandbox the process or isolate system wallpaper settings.
