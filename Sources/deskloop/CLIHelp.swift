import Foundation

enum CLIHelp {
    static let commands: [String: String] = [
        "apply": "apply <id|path|url> [--daemon] [--source name] [--json]\n    Loop a video on every display. Foreground playback ends on Ctrl+C.\n    Use --daemon for background playback. --json requires --daemon.\n    Stop an existing engine before applying another video.\n    Success acknowledges engine startup, not successful video decoding.",
        "status": "status [--json]\n    Show the recorded engine process and connected display count.",
        "stop": "stop [--json]\n    Stop the recorded engine. Already stopped is a successful no-op.",
        "featured": "featured [limit] [--source name] [--json]\n    List wallpapers. limit is a positive integer; default: 15.",
        "search": "search <query> [--source name] [--json]\n    Search wallpapers. Quote queries containing spaces. Use returned IDs to apply.",
        "download": "download <id> [-o path] [--source name]\n    Download a source item. Default output: wallpaper_<sanitized-id>.mp4.",
        "set-static": "set-static <id|path|url> [--source name]\n    Extract a video frame and set the permanent system wallpaper on all displays.",
        "sources": "sources [--json]\n    List registered sources. Default source: apple. Also available: local.",
        "cache": "cache [list|clear] [--json]\n    List downloaded videos by default, or delete them with clear.\n    Static wallpaper frames and the Apple catalog are retained.",
        "mcp": "mcp\n    Serve MCP over newline-delimited JSON on stdin/stdout until EOF.\n    Configure your MCP client with command deskloop and args [\"mcp\"].",
        "version": "version [--json]\n    Show the installed version. Aliases: --version, -v."
    ]

    static func text(for command: String?) -> String {
        if let command, let detail = commands[command] {
            return "Usage: deskloop \(detail)\n\nRun 'deskloop --help' for all commands."
        }
        return """
        deskloop \(deskloopVersion) - Live video wallpaper for macOS

        Usage: deskloop <command> [options]
               deskloop <command> --help
               deskloop help <command>

        Commands:
          apply <id|path|url>   Play a video on all displays
          status                Show engine status
          stop                  Stop playback
          featured [limit]      List wallpapers (default: 15)
          search <query>        Search wallpapers
          download <id>         Save a video (-o path selects the destination)
          set-static <target>   Set a video frame as permanent system wallpaper
          sources               List sources
          cache [list|clear]    Inspect or clear downloaded videos
          mcp                   Start the MCP stdio server
          version               Show version

        Options:
          --source <name>       apple (default) or local; source commands only
          --daemon              Background playback; apply only
          --json                JSON for version, sources, featured, search,
                                apply --daemon, status, stop, and cache
          -h, --help            Show help
          -v, --version         Show version

        Examples:
          deskloop search "Greenland" --json
          deskloop apply "<ID from search>" --daemon --json
          deskloop apply ~/Movies/loop.mp4 --daemon
          deskloop status --json
          deskloop stop --json

        Data: ~/.deskloop (override with DESKLOOP_HOME).
        Exit codes: 0 = success, 1 = failure.
        JSON failures contain error.domain, error.code, and error.message on stdout.
        Other errors go to stderr. Help is plain text, without ANSI escapes.
        Aliases: live = apply; trending and list = featured.
        Requires macOS 13 or newer and a logged-in graphical session for playback.
        """
    }
}
