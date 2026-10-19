import Foundation
import AppKit
import DeskloopCore

public final class MCPServer: Sendable {
    private let sources: [String: WallpaperSource]

    public init(sources: [String: WallpaperSource]) {
        self.sources = sources
    }

    public func run() {
        let stdin = FileHandle.standardInput

        var buffer = Data()
        let delimiter = "\n".data(using: .utf8)!

        while true {
            let chunk = stdin.availableData
            if chunk.isEmpty {
                break // EOF received, client closed stdio
            }
            buffer.append(chunk)

            while let range = buffer.range(of: delimiter) {
                let lineData = buffer.subdata(in: 0..<range.lowerBound)
                buffer.removeSubrange(0..<range.upperBound)

                if lineData.isEmpty { continue }

                guard let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                    continue
                }

                handleMessage(json)
            }
        }
    }

    private func handleMessage(_ json: [String: Any]) {
        let id = json["id"]
        let method = json["method"] as? String ?? ""
        let params = json["params"] as? [String: Any] ?? [:]

        // If it's a notification without an id, handle and return
        if id == nil {
            handleNotification(method: method, params: params)
            return
        }

        switch method {
        case "initialize":
            let result: [String: Any] = [
                "protocolVersion": "2024-11-05",
                "capabilities": [
                    "tools": [String: Any]()
                ],
                "serverInfo": [
                    "name": "deskloop",
                    "version": deskloopVersion
                ]
            ]
            sendResponse(id: id, result: result)

        case "ping":
            sendResponse(id: id, result: [String: Any]())

        case "tools/list":
            let tools = getToolDefinitions()
            sendResponse(id: id, result: ["tools": tools])

        case "tools/call":
            let toolName = params["name"] as? String ?? ""
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            executeTool(name: toolName, arguments: arguments, id: id)

        default:
            sendError(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    private func handleNotification(method: String, params: [String: Any]) {
        // e.g., notifications/initialized
        if method == "notifications/initialized" {
            // Client initialization acknowledged
        }
    }

    private func executeTool(name: String, arguments: [String: Any], id: Any?) {
        do {
            switch name {
            case "apply_wallpaper":
                guard let target = arguments["target"] as? String, !target.isEmpty else {
                    sendToolError(id: id, message: "Missing required argument 'target'")
                    return
                }
                let sourceName = (arguments["source"] as? String)?.lowercased() ?? "apple"
                guard let source = sources[sourceName] else {
                    sendToolError(id: id, message: "Unknown source '\(sourceName)'. Available: \(sources.keys.sorted().joined(separator: ", "))")
                    return
                }

                let videoURL = try resolveVideoURL(target: target, source: source, silent: true)

                // Start daemon
                let executablePath: String
                if let path = Bundle.main.executablePath, FileManager.default.fileExists(atPath: path) {
                    executablePath = path
                } else {
                    executablePath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
                }

                let logFile = EngineProcessController.logFileURL
                FileManager.default.createFile(atPath: logFile.path, contents: nil)
                let logHandle = try FileHandle(forWritingTo: logFile)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = ["apply", videoURL.isFileURL ? videoURL.path : videoURL.absoluteString]
                process.standardOutput = logHandle
                process.standardError = logHandle
                try process.run()

                let text = """
                Started live wallpaper daemon (PID: \(process.processIdentifier))
                Video: \(videoURL.isFileURL ? videoURL.path : videoURL.absoluteString)
                Displays: \(NSScreen.screens.count) connected
                Logs: \(logFile.path)
                """
                sendToolSuccess(id: id, text: text)

            case "stop_wallpaper":
                let result = try EngineProcessController.stopRunningEngine()
                sendToolSuccess(id: id, text: result.message)

            case "get_status":
                guard let state = try? EngineProcessController.loadState() else {
                    sendToolSuccess(id: id, text: "Status: Stopped (No live wallpaper engine running)")
                    return
                }
                let isRunning = EngineProcessController.isRunning(state)
                if !isRunning {
                    try? EngineProcessController.clearState(ownedBy: state.pid)
                    sendToolSuccess(id: id, text: "Status: Stopped (Cleaned up stale PID \(state.pid))")
                } else {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .full
                    let uptime = formatter.localizedString(for: state.startTime, relativeTo: Date())
                    let screens = NSScreen.screens.count
                    let text = """
                    Status: Running
                    PID: \(state.pid)
                    Video: \(state.videoPath)
                    Started: \(uptime)
                    Connected Displays: \(screens)
                    """
                    sendToolSuccess(id: id, text: text)
                }

            case "search_wallpapers":
                guard let query = arguments["query"] as? String, !query.isEmpty else {
                    sendToolError(id: id, message: "Missing required argument 'query'")
                    return
                }
                let limit = arguments["limit"] as? Int ?? 10
                let source = sources["apple"]!
                let items = try runAsync { try await source.search(query: query) }
                let results = Array(items.prefix(limit))
                if results.isEmpty {
                    sendToolSuccess(id: id, text: "No wallpapers found matching '\(query)'.")
                } else {
                    let lines = results.map { "• \($0.title) [ID: \($0.id)] (\($0.resolution))" }
                    sendToolSuccess(id: id, text: "Found \(results.count) wallpapers:\n" + lines.joined(separator: "\n"))
                }

            case "list_featured":
                let limit = arguments["limit"] as? Int ?? 10
                let source = sources["apple"]!
                let items = try runAsync { try await source.fetchFeatured(limit: limit) }
                let results = Array(items.prefix(limit))
                let lines = results.map { "• \($0.title) [ID: \($0.id)] (\($0.resolution))" }
                sendToolSuccess(id: id, text: "Featured Apple 4K Aerials:\n" + lines.joined(separator: "\n"))

            case "set_static_wallpaper":
                guard let target = arguments["target"] as? String, !target.isEmpty else {
                    sendToolError(id: id, message: "Missing required argument 'target'")
                    return
                }
                let sourceName = (arguments["source"] as? String)?.lowercased() ?? "apple"
                guard let source = sources[sourceName] else {
                    sendToolError(id: id, message: "Unknown source '\(sourceName)'")
                    return
                }
                let fileURL = try resolveVideoURL(target: target, source: source, silent: true)
                try StaticWallpaperService.setDesktopImage(from: fileURL)
                sendToolSuccess(id: id, text: "Successfully set desktop background image to frame from: \(fileURL.lastPathComponent)")

            default:
                sendToolError(id: id, message: "Unknown tool '\(name)'")
            }
        } catch {
            sendToolError(id: id, message: error.localizedDescription)
        }
    }

    private func sendToolSuccess(id: Any?, text: String) {
        let result: [String: Any] = [
            "content": [
                [
                    "type": "text",
                    "text": text
                ]
            ],
            "isError": false
        ]
        sendResponse(id: id, result: result)
    }

    private func sendToolError(id: Any?, message: String) {
        let result: [String: Any] = [
            "content": [
                [
                    "type": "text",
                    "text": "Error: \(message)"
                ]
            ],
            "isError": true
        ]
        sendResponse(id: id, result: result)
    }

    private func sendResponse(id: Any?, result: [String: Any]) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "result": result
        ]
        if let id = id {
            response["id"] = id
        }
        writeJSON(response)
    }

    private func sendError(id: Any?, code: Int, message: String) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": code,
                "message": message
            ]
        ]
        if let id = id {
            response["id"] = id
        }
        writeJSON(response)
    }

    private func writeJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        let line = jsonString + "\n"
        if let outputData = line.data(using: .utf8) {
            FileHandle.standardOutput.write(outputData)
        }
    }

    private func getToolDefinitions() -> [[String: Any]] {
        return [
            [
                "name": "apply_wallpaper",
                "description": "Set a video file path, URL, or Apple Aerial as the live looping wallpaper across all connected displays.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "target": [
                            "type": "string",
                            "description": "Path to local .mp4/.mov video, URL, or Apple Aerial name/ID (e.g. 'Greenland', 'Hawaii', 'Space')"
                        ],
                        "source": [
                            "type": "string",
                            "description": "Wallpaper source: 'apple' (default) or 'local'",
                            "enum": ["apple", "local"]
                        ]
                    ],
                    "required": ["target"]
                ] as [String: Any]
            ],
            [
                "name": "stop_wallpaper",
                "description": "Stop the currently running live wallpaper engine.",
                "inputSchema": [
                    "type": "object",
                    "properties": [String: Any]()
                ] as [String: Any]
            ],
            [
                "name": "get_status",
                "description": "Get current live wallpaper status, PID, active video path, and connected displays.",
                "inputSchema": [
                    "type": "object",
                    "properties": [String: Any]()
                ] as [String: Any]
            ],
            [
                "name": "search_wallpapers",
                "description": "Search available Apple 4K Aerial wallpapers by keyword or location.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "Search keyword (e.g. 'Los Angeles', 'Space', 'Underwater')"
                        ],
                        "limit": [
                            "type": "integer",
                            "description": "Maximum number of results to return (default 10)"
                        ]
                    ],
                    "required": ["query"]
                ] as [String: Any]
            ],
            [
                "name": "list_featured",
                "description": "List featured official Apple 4K Aerial wallpapers.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "limit": [
                            "type": "integer",
                            "description": "Maximum number of results to return (default 10)"
                        ]
                    ]
                ] as [String: Any]
            ],
            [
                "name": "set_static_wallpaper",
                "description": "Set the first frame of a video or Apple Aerial as the native macOS static desktop wallpaper.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "target": [
                            "type": "string",
                            "description": "Path to video file, URL, or Apple Aerial name"
                        ],
                        "source": [
                            "type": "string",
                            "description": "Source name: 'apple' (default) or 'local'",
                            "enum": ["apple", "local"]
                        ]
                    ],
                    "required": ["target"]
                ] as [String: Any]
            ]
        ]
    }
}
