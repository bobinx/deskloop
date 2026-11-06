import Foundation

enum CLIHelp {
    static let commands: [String: String] = [
        "run": "run <path|url> [--daemon] [--json]\n    Loop a video on all displays. Foreground playback ends on Ctrl+C.\n    Use --daemon for background playback. --json requires --daemon.\n    Stop an existing engine before starting another video.",
        "apply": "apply <path|url> [--daemon] [--json]\n    Alias for 'run'.",
        "status": "status [--json]\n    Show running wallpaper process status, active displays, and uptime.",
        "stop": "stop [--json]\n    Stop the running wallpaper engine.",
        "version": "version [--json]\n    Show installed version. Aliases: --version, -v."
    ]

    static func text(for command: String?) -> String {
        let topic = command.map { ["live": "run", "apply": "run"][$0] ?? $0 }
        if let topic, let detail = commands[topic] {
            return "Usage: deskloop \(detail)\n\nRun 'deskloop --help' for general usage."
        }
        return """
        deskloop \(deskloopVersion) - Minimal live video wallpaper engine for macOS

        Usage:
          deskloop run <path|url> [--daemon] [--json]
          deskloop <path|url> [--daemon]
          deskloop status [--json]
          deskloop stop [--json]
          deskloop --help / -h
          deskloop --version / -v

        Commands:
          run <path|url>   Play a local video (.mp4, .mov, .m4v) or URL across all displays
          status           Show running engine PID, active video, and connected displays
          stop             Stop playback and restore default desktop wallpaper
          version          Show version

        Options:
          --daemon         Run playback in the background as a detached process
          --json           Format output as machine-readable JSON
          -h, --help       Show this help message
          -v, --version    Show version

        Examples:
          deskloop run ~/Movies/loop.mp4 --daemon
          deskloop ~/Movies/loop.mp4 --daemon
          deskloop run "https://example.com/loop.mp4" --daemon
          deskloop status --json
          deskloop stop

        Power management:
          Playback pauses automatically during window occlusion, display sleep,
          system sleep, and Low Power Mode.
        """
    }
}
