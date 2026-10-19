import Foundation
import DeskloopCore

enum CLICommand {
    case help
    case version(json: Bool)
    case sources(json: Bool)
    case featured(source: WallpaperSource, limit: Int, json: Bool)
    case search(source: WallpaperSource, query: String, json: Bool)
    case download(source: WallpaperSource, id: String, outputPath: String)
    case apply(source: WallpaperSource, target: String, daemon: Bool)
    case status(json: Bool)
    case stop(json: Bool)
    case setStatic(source: WallpaperSource, target: String)
    case cache(CacheAction, json: Bool)
    case mcp
}

enum CacheAction {
    case list
    case clear
}

enum CLICommandParser {
    static func parse(_ arguments: [String], sources: [String: WallpaperSource]) throws -> CLICommand {
        guard !arguments.isEmpty else { return .help }
        let (tokens, source, sourceWasProvided, isJSON) = try extractOptions(from: arguments)
        guard let rawCommand = tokens.first else { return .help }
        let command = rawCommand.lowercased()
        let values = Array(tokens.dropFirst())

        switch command {
        case "-h", "--help", "help":
            try require(values.isEmpty && !sourceWasProvided, usage: "deskloop --help")
            return .help
        case "-v", "--version", "version":
            try require(values.isEmpty && !sourceWasProvided, usage: "deskloop --version [--json]")
            return .version(json: isJSON)
        case "sources":
            try require(values.isEmpty && !sourceWasProvided, usage: "deskloop sources [--json]")
            return .sources(json: isJSON)
        case "featured", "trending", "list":
            guard values.count <= 1 else {
                throw usage("deskloop featured [limit] [--source name] [--json]")
            }
            let limit = try positiveLimit(values.first)
            return .featured(source: try resolveSource(source, sources: sources), limit: limit, json: isJSON)
        case "search":
            guard !values.isEmpty else { throw usage("deskloop search <query> [--source name] [--json]") }
            return .search(source: try resolveSource(source, sources: sources), query: values.joined(separator: " "), json: isJSON)
        case "download":
            guard let id = values.first else { throw usage("deskloop download <id> [-o path] [--source name]") }
            let outputPath: String
            let outputArguments = Array(values.dropFirst())
            switch outputArguments.count {
            case 0:
                outputPath = "wallpaper_\(Utilities.sanitizeFilename(id)).mp4"
            case 1 where !outputArguments[0].hasPrefix("-"):
                outputPath = outputArguments[0]
            case 2 where outputArguments[0] == "-o":
                outputPath = outputArguments[1]
            default:
                throw usage("deskloop download <id> [-o path] [--source name]")
            }
            return .download(source: try resolveSource(source, sources: sources), id: id, outputPath: outputPath)
        case "apply", "live":
            guard let target = values.first else {
                throw usage("deskloop apply <id|path|url> [--daemon] [--source name]")
            }
            let options = Array(values.dropFirst())
            guard options.isEmpty || options == ["--daemon"] else {
                throw usage("deskloop apply <id|path|url> [--daemon] [--source name]")
            }
            return .apply(source: try resolveSource(source, sources: sources), target: target, daemon: options.contains("--daemon"))
        case "status":
            try require(values.isEmpty && !sourceWasProvided, usage: "deskloop status [--json]")
            return .status(json: isJSON)
        case "stop":
            try require(values.isEmpty && !sourceWasProvided, usage: "deskloop stop [--json]")
            return .stop(json: isJSON)
        case "set-static":
            guard values.count == 1 else {
                throw usage("deskloop set-static <id|path|url> [--source name]")
            }
            return .setStatic(source: try resolveSource(source, sources: sources), target: values[0])
        case "cache":
            guard values.count <= 1 && !sourceWasProvided else {
                throw usage("deskloop cache [list|clear] [--json]")
            }
            switch values.first?.lowercased() ?? "list" {
            case "list", "ls": return .cache(.list, json: isJSON)
            case "clear", "clean", "purge": return .cache(.clear, json: isJSON)
            default: throw usage("deskloop cache [list|clear] [--json]")
            }
        case "mcp":
            try require(values.isEmpty && !sourceWasProvided, usage: "deskloop mcp")
            return .mcp
        default:
            throw NSError(domain: "deskloop", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown command: \(rawCommand)"])
        }
    }

    private static func extractOptions(from arguments: [String]) throws -> (tokens: [String], source: String, wasProvided: Bool, isJSON: Bool) {
        var tokens: [String] = []
        var source = "apple"
        var sourceWasProvided = false
        var isJSON = false
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--source" {
                guard !sourceWasProvided, index + 1 < arguments.count else {
                    throw usage("--source requires one source name and may be provided once")
                }
                source = arguments[index + 1].lowercased()
                sourceWasProvided = true
                index += 2
            } else if argument == "--json" {
                isJSON = true
                index += 1
            } else {
                tokens.append(argument)
                index += 1
            }
        }
        return (tokens, source, sourceWasProvided, isJSON)
    }

    private static func resolveSource(_ name: String, sources: [String: WallpaperSource]) throws -> WallpaperSource {
        guard let source = sources[name] else {
            throw NSError(
                domain: "deskloop",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unknown source '\(name)'. Available sources: \(sources.keys.sorted().joined(separator: ", "))."]
            )
        }
        return source
    }

    private static func positiveLimit(_ value: String?) throws -> Int {
        guard let value else { return 15 }
        guard let limit = Int(value), limit > 0 else {
            throw NSError(domain: "deskloop", code: 3, userInfo: [NSLocalizedDescriptionKey: "Limit must be a positive integer."])
        }
        return limit
    }

    private static func require(_ condition: Bool, usage: String) throws {
        guard condition else { throw self.usage(usage) }
    }

    private static func usage(_ message: String) -> NSError {
        NSError(domain: "deskloop", code: 4, userInfo: [NSLocalizedDescriptionKey: "Usage: \(message)"])
    }
}
