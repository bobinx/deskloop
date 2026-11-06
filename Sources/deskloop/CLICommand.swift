import Foundation

enum CLICommand {
    case run(target: String, daemon: Bool, json: Bool)
    case status(json: Bool)
    case stop(json: Bool)
    case version(json: Bool)
    case help(command: String?)
}

enum CLICommandParser {
    static func parse(_ arguments: [String]) throws -> CLICommand {
        guard !arguments.isEmpty else { return .help(command: nil) }

        let (tokens, isDaemon, isJSON) = extractOptions(from: arguments)
        guard let first = tokens.first else {
            if isJSON {
                throw usage("deskloop <command> [--json]")
            }
            return .help(command: nil)
        }

        let command = first.lowercased()
        let values = Array(tokens.dropFirst())

        if command == "help" || command == "--help" || command == "-h" {
            let topic = command == "help" ? values.first?.lowercased() : nil
            return .help(command: topic)
        }

        if values.contains("--help") || values.contains("-h") {
            return .help(command: command)
        }

        switch command {
        case "-v", "--version", "version":
            guard values.isEmpty && !isDaemon else {
                throw usage("deskloop version [--json]")
            }
            return .version(json: isJSON)

        case "status":
            guard values.isEmpty && !isDaemon else {
                throw usage("deskloop status [--json]")
            }
            return .status(json: isJSON)

        case "stop":
            guard values.isEmpty && !isDaemon else {
                throw usage("deskloop stop [--json]")
            }
            return .stop(json: isJSON)

        case "run", "apply":
            guard let target = values.first, values.count == 1 else {
                throw usage("deskloop run <path|url> [--daemon] [--json]")
            }
            if isJSON && !isDaemon {
                throw usage("deskloop run <path|url> --daemon --json")
            }
            return .run(target: target, daemon: isDaemon, json: isJSON)

        default:
            if values.isEmpty {
                let target = first
                let isLikelyTarget = target.hasPrefix("http://")
                    || target.hasPrefix("https://")
                    || target.hasPrefix("/")
                    || target.hasPrefix("~")
                    || target.hasPrefix(".")
                    || target.contains(".")
                if isLikelyTarget {
                    if isJSON && !isDaemon {
                        throw usage("deskloop <path|url> --daemon --json")
                    }
                    return .run(target: target, daemon: isDaemon, json: isJSON)
                }
            }
            throw NSError(domain: "deskloop", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unknown command: '\(first)'."
            ])
        }
    }

    private static func extractOptions(from arguments: [String]) -> (tokens: [String], isDaemon: Bool, isJSON: Bool) {
        var tokens: [String] = []
        var isDaemon = false
        var isJSON = false

        for arg in arguments {
            if arg == "--daemon" {
                isDaemon = true
            } else if arg == "--json" {
                isJSON = true
            } else {
                tokens.append(arg)
            }
        }
        return (tokens, isDaemon, isJSON)
    }

    private static func usage(_ message: String) -> NSError {
        NSError(domain: "deskloop", code: 4, userInfo: [NSLocalizedDescriptionKey: "Usage: \(message)"])
    }
}
