import Foundation
import AppKit
import DeskloopCore

let deskloopVersion = "1.1.0"

func printUsage() {
    print("""
    \u{001B}[1;36mdeskloop\u{001B}[0m v\(deskloopVersion) - Native Live Wallpaper Engine for macOS

    \u{001B}[1mUSAGE:\u{001B}[0m
        deskloop <command> [options]

    \u{001B}[1mCOMMANDS:\u{001B}[0m
        \u{001B}[32mapply\u{001B}[0m, \u{001B}[32mlive\u{001B}[0m <id|path|url> [--daemon] Apply live video wallpaper across all displays
        \u{001B}[32mstatus\u{001B}[0m [--json]                         Check running wallpaper engine status
        \u{001B}[32mstop\u{001B}[0m [--json]                           Stop running live wallpaper daemon
        \u{001B}[32mfeatured\u{001B}[0m [limit] [--json]               Browse featured 4K wallpapers
        \u{001B}[32msearch\u{001B}[0m <query> [--json]                 Search wallpapers by keyword
        \u{001B}[32mdownload\u{001B}[0m <id> [-o path]                 Download video wallpaper to local disk
        \u{001B}[32mset-static\u{001B}[0m <id|path|url>               Set first frame as native static desktop wallpaper
        \u{001B}[32msources\u{001B}[0m [--json]                        List available wallpaper sources
        \u{001B}[32mcache\u{001B}[0m [list|clear] [--json]             Manage downloaded wallpaper cache
        \u{001B}[32mmcp\u{001B}[0m                                      Start Model Context Protocol (MCP) server over stdio

    \u{001B}[1mOPTIONS:\u{001B}[0m
        \u{001B}[33m--source <name>\u{001B}[0m                       Select source: \u{001B}[1mapple\u{001B}[0m (default) or \u{001B}[1mlocal\u{001B}[0m
        \u{001B}[33m--daemon\u{001B}[0m                              Run silently in the background
        \u{001B}[33m--json\u{001B}[0m                                Output results in machine-readable JSON format
        \u{001B}[33m-h, --help\u{001B}[0m                            Show this help menu
        \u{001B}[33m-v, --version\u{001B}[0m                         Show version information

    \u{001B}[1mPOWER MANAGEMENT:\u{001B}[0m
        • Occlusion auto-pause: Video decoding pauses when windows cover the desktop
        • Display sleep friendly: Lets macOS screens sleep normally when idle
        • Sleep tracking: 0% CPU and 0% GPU usage during display or system sleep
        • Low Power Mode detection: Automatically suspends playback on battery saver
        • Hardware accelerated: VideoToolbox decoding directly to Metal surfaces

    \u{001B}[1mEXAMPLES:\u{001B}[0m
        deskloop featured 10
        deskloop search "Greenland" --json
        deskloop apply "Korea and Japan Night" --daemon
        deskloop apply ~/Movies/wallpaper.mp4 --daemon
        deskloop status --json
        deskloop stop
        deskloop mcp
    """)
}

func getRegisteredSources() -> [String: WallpaperSource] {
    let apple = AppleAerialSource()
    let local = LocalSource()
    return [
        apple.name: apple,
        local.name: local
    ]
}

func printJSON<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(value), let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

func printJSONObject(_ dict: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
       let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

func formatTable(_ rows: [[String]], headers: [String]) {
    var colWidths = headers.map { $0.count }
    for row in rows {
        for (i, val) in row.enumerated() {
            if i < colWidths.count {
                colWidths[i] = max(colWidths[i], val.count)
            }
        }
    }

    let headerLine = headers.enumerated().map { i, h in
        h.padding(toLength: colWidths[i], withPad: " ", startingAt: 0)
    }.joined(separator: "  |  ")

    let separator = colWidths.map { String(repeating: "-", count: $0) }.joined(separator: "--+--")

    print("\u{001B}[1m" + headerLine + "\u{001B}[0m")
    print(separator)
    for row in rows {
        let line = row.enumerated().map { i, val in
            val.padding(toLength: colWidths[i], withPad: " ", startingAt: 0)
        }.joined(separator: "  |  ")
        print(line)
    }
}

private final class AsyncResultBox<T: Sendable>: @unchecked Sendable {
    var result: Result<T, Error>?
}

func runAsync<T: Sendable>(_ block: @escaping @Sendable () async throws -> T) throws -> T {
    let box = AsyncResultBox<T>()
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        do {
            let val = try await block()
            box.result = .success(val)
        } catch {
            box.result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    guard let result = box.result else {
        throw NSError(domain: "deskloop", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task failed to return a result."])
    }
    switch result {
    case .success(let val): return val
    case .failure(let err): throw err
    }
}

func resolveVideoURL(target: String, source: WallpaperSource, silent: Bool = false) throws -> URL {
    let expanded = NSString(string: target).expandingTildeInPath
    if FileManager.default.fileExists(atPath: expanded) {
        return URL(fileURLWithPath: expanded)
    }

    if target.lowercased().hasPrefix("http://") || target.lowercased().hasPrefix("https://") {
        guard let url = URL(string: target) else {
            throw NSError(domain: "deskloop", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL."])
        }
        return url
    }

    let cacheDir = EngineProcessController.appDirectory.appendingPathComponent("cache", isDirectory: true)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

    let safeTarget = Utilities.sanitizeFilename(target)
    let cacheFileName = "\(source.name)_\(safeTarget).mp4"
    let localCache = cacheDir.appendingPathComponent(cacheFileName)

    if FileManager.default.fileExists(atPath: localCache.path) {
        return localCache
    }

    if !silent {
        print("Resolving '\(target)' from source [\(source.name)]...")
    }
    var matched = try runAsync({ try await source.resolve(id: target) })
    if matched == nil {
        let searchRes = try runAsync({ try await source.search(query: target) })
        matched = searchRes.first
    }

    guard let item = matched else {
        throw NSError(domain: "deskloop", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Could not resolve '\(target)' in source '\(source.name)'."
        ])
    }

    if item.videoURL.isFileURL {
        return item.videoURL
    }

    if !silent {
        print("Downloading \"\(item.title)\"...")
    }
    try runAsync {
        try await FileDownloader.shared.download(from: item.videoURL, to: localCache) { progress in
            if !silent {
                let percent = Int(progress * 100)
                let barLength = 30
                let filled = Int(progress * Double(barLength))
                let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: max(0, barLength - filled))
                print("\r[\(bar)] \(percent)%", terminator: "")
                fflush(stdout)
            }
        }
    }
    if !silent {
        print("\nDownload complete.")
    }
    return localCache
}

let sources = getRegisteredSources()
do {
    let command = try CLICommandParser.parse(
        Array(CommandLine.arguments.dropFirst()),
        sources: sources
    )
    switch command {
    case .help:
        printUsage()
        exit(0)

    case let .version(json):
        if json {
            printJSONObject(["name": "deskloop", "version": deskloopVersion])
        } else {
            print("deskloop version \(deskloopVersion)")
        }
        exit(0)

    case let .sources(json):
        let all = getRegisteredSources()
        if json {
            let list = all.values.sorted(by: { $0.name < $1.name }).map {
                ["name": $0.name, "description": $0.description]
            }
            printJSONObject(["sources": list])
        } else {
            let rows = all.values.sorted(by: { $0.name < $1.name }).map { [$0.name, $0.description] }
            print("\n\u{001B}[1;32mAvailable Wallpaper Sources:\u{001B}[0m")
            formatTable(rows, headers: ["Source Name", "Description"])
        }
        exit(0)

    case let .featured(sourceName, limit, json):
        let source = sourceName
        let items = try runAsync { try await source.fetchFeatured(limit: limit) }
        if json {
            printJSON(items)
        } else {
            let rows = items.map { [
                $0.id,
                $0.title,
                $0.category ?? "N/A",
                $0.resolution,
                $0.duration
            ] }
            print("\n\u{001B}[1;32mFeatured Wallpapers (Source: \(source.name)):\u{001B}[0m (\(items.count) items)")
            formatTable(rows, headers: ["ID", "Title", "Category", "Resolution", "Duration"])
        }
        exit(0)

    case let .search(sourceName, query, json):
        let source = sourceName
        if !json {
            print("Searching [\(source.name)] for: \"\(query)\"...")
        }
        let results = try runAsync { try await source.search(query: query) }
        if json {
            printJSON(results)
        } else {
            if results.isEmpty {
                print("No wallpapers found matching \"\(query)\" in source '\(source.name)'.")
                exit(0)
            }
            let rows = results.prefix(25).map { [
                $0.id,
                $0.title,
                $0.category ?? "N/A",
                $0.resolution,
                $0.duration
            ] }
            print("\n\u{001B}[1;32mSearch Results:\u{001B}[0m (\(results.count) found)")
            formatTable(rows, headers: ["ID", "Title", "Category", "Resolution", "Duration"])
        }
        exit(0)

    case let .download(sourceName, targetId, outputPath):
        let source = sourceName
        print("Resolving '\(targetId)' from source [\(source.name)]...")
        guard let item = try runAsync({ try await source.resolve(id: targetId) }) else {
            print("\u{001B}[31mError:\u{001B}[0m Wallpaper '\(targetId)' not found in source '\(source.name)'.")
            exit(1)
        }

        let destinationURL = URL(fileURLWithPath: outputPath)
        print("Downloading \"\(item.title)\" to \(destinationURL.lastPathComponent)...")
        try runAsync {
            try await FileDownloader.shared.download(from: item.videoURL, to: destinationURL) { progress in
                let percent = Int(progress * 100)
                let barLength = 30
                let filled = Int(progress * Double(barLength))
                let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: max(0, barLength - filled))
                print("\r[\(bar)] \(percent)%", terminator: "")
                fflush(stdout)
            }
        }
        print("\n\u{001B}[32mSaved to:\u{001B}[0m \(destinationURL.path)")
        exit(0)

    case let .apply(sourceName, target, isDaemon):
        let source = sourceName
        let videoURL = try resolveVideoURL(target: target, source: source)

        if isDaemon {
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

            print("\u{001B}[32mStarted live wallpaper daemon (PID: \(process.processIdentifier))\u{001B}[0m")
            print("Video: \(videoURL.isFileURL ? videoURL.path : videoURL.absoluteString)")
            print("Logs: \(logFile.path)")
            print("Run \u{001B}[1mdeskloop status\u{001B}[0m or \u{001B}[1mdeskloop stop\u{001B}[0m to manage.")
            exit(0)
        } else {
            print("\u{001B}[32mStarting live video wallpaper on all connected displays...\u{001B}[0m")
            print("Video: \(videoURL.isFileURL ? videoURL.path : videoURL.absoluteString)")
            print("Power management active: occlusion auto-pause, low power mode awareness, display sleep hooks.")
            print("Press \u{001B}[1mCtrl+C\u{001B}[0m to stop.")

            let engineLease = try EngineProcessController.acquireEngineLease()
            try EngineProcessController.saveState(videoURL: videoURL)
            let signalHandler = ApplicationSignalHandler {
                WallpaperEngine.shared.stop()
                do {
                    try EngineProcessController.clearState(ownedBy: getpid())
                } catch {
                    fputs("deskloop: failed to clear engine state: \(error.localizedDescription)\n", stderr)
                }
                NSApplication.shared.terminate(nil)
            }
            _ = signalHandler
            WallpaperEngine.shared.start(with: videoURL)
            withExtendedLifetime((signalHandler, engineLease)) {
                NSApplication.shared.run()
            }
        }

    case let .status(json):
        guard let state = try EngineProcessController.loadState() else {
            if json {
                printJSONObject(["status": "stopped"])
            } else {
                print("Status: \u{001B}[33mStopped\u{001B}[0m (No live wallpaper engine running)")
            }
            exit(0)
        }

        let isRunning = EngineProcessController.isRunning(state)
        if !isRunning {
            try EngineProcessController.clearState(ownedBy: state.pid)
            if json {
                printJSONObject([
                    "status": "stopped",
                    "cleanedStalePID": state.pid
                ])
            } else {
                print("Status: \u{001B}[33mStopped\u{001B}[0m (Cleaned up stale process record PID \(state.pid))")
            }
            exit(0)
        }

        let screenCount = NSScreen.screens.count
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let uptimeString = formatter.localizedString(for: state.startTime, relativeTo: Date())

        if json {
            let iso = ISO8601DateFormatter()
            printJSONObject([
                "status": "running",
                "pid": state.pid,
                "video": state.videoPath,
                "startTime": iso.string(from: state.startTime),
                "uptime": uptimeString,
                "displays": screenCount,
                "logFile": EngineProcessController.logFileURL.path
            ])
        } else {
            print("""
            Status:          \u{001B}[32mRunning\u{001B}[0m
            Process ID:      \(state.pid)
            Active Video:    \(state.videoPath)
            Started:         \(uptimeString)
            Active Displays: \(screenCount) connected display\(screenCount == 1 ? "" : "s")
            Log File:        \(EngineProcessController.logFileURL.path)
            """)
        }
        exit(0)

    case let .stop(json):
        let result = try EngineProcessController.stopRunningEngine()
        if json {
            printJSONObject([
                "success": result.success,
                "message": result.message
            ])
        } else {
            if result.success {
                print("\u{001B}[32m\(result.message)\u{001B}[0m")
            } else {
                print(result.message)
            }
        }
        exit(0)

    case let .setStatic(sourceName, target):
        let source = sourceName
        let fileURL = try resolveVideoURL(target: target, source: source)

        print("Setting static wallpaper for all displays...")
        try StaticWallpaperService.setDesktopImage(from: fileURL)
        print("\u{001B}[32mSuccessfully updated desktop wallpaper.\u{001B}[0m")
        exit(0)

    case let .cache(action, json):
        let cacheDir = EngineProcessController.appDirectory.appendingPathComponent("cache", isDirectory: true)

        switch action {
        case .clear:
            guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else {
                if json {
                    printJSONObject(["clearedFiles": 0, "freedBytes": 0, "freedSize": "0 B"])
                } else {
                    print("Cache directory is empty.")
                }
                exit(0)
            }
            var deletedCount = 0
            var freedBytes: Int64 = 0
            for file in files {
                if file.lastPathComponent == "apple_entries.json" { continue }
                if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                    freedBytes += Int64(size)
                }
                try? FileManager.default.removeItem(at: file)
                deletedCount += 1
            }
            if json {
                printJSONObject([
                    "clearedFiles": deletedCount,
                    "freedBytes": freedBytes,
                    "freedSize": Utilities.formatBytes(freedBytes)
                ])
            } else {
                print("\u{001B}[32mCleared \(deletedCount) cached video\(deletedCount == 1 ? "" : "s") (\(Utilities.formatBytes(freedBytes)) freed).\u{001B}[0m")
            }
            exit(0)

        case .list:
            guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else {
                if json {
                    printJSONObject(["cacheDirectory": cacheDir.path, "files": [], "totalBytes": 0, "totalSize": "0 B"])
                } else {
                    print("Cache is empty.")
                }
                exit(0)
            }
            let videoFiles = files.filter { $0.pathExtension.lowercased() == "mp4" || $0.pathExtension.lowercased() == "mov" }
            if videoFiles.isEmpty {
                if json {
                    printJSONObject(["cacheDirectory": cacheDir.path, "files": [], "totalBytes": 0, "totalSize": "0 B"])
                } else {
                    print("Cache is empty (no downloaded videos in \(cacheDir.path)).")
                }
                exit(0)
            }

            var totalBytes: Int64 = 0
            var rows: [[String]] = []
            var fileList: [[String: Any]] = []
            for file in videoFiles {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                totalBytes += Int64(size)
                rows.append([file.lastPathComponent, Utilities.formatBytes(Int64(size))])
                fileList.append([
                    "name": file.lastPathComponent,
                    "bytes": size,
                    "size": Utilities.formatBytes(Int64(size))
                ])
            }

            if json {
                printJSONObject([
                    "cacheDirectory": cacheDir.path,
                    "files": fileList,
                    "totalBytes": totalBytes,
                    "totalSize": Utilities.formatBytes(totalBytes)
                ])
            } else {
                print("\n\u{001B}[1;32mCached Video Wallpapers (\(cacheDir.path)):\u{001B}[0m")
                formatTable(rows, headers: ["File Name", "Size"])
                print("\nTotal disk usage: \u{001B}[1m\(Utilities.formatBytes(totalBytes))\u{001B}[0m across \(videoFiles.count) file\(videoFiles.count == 1 ? "" : "s").")
                print("Run \u{001B}[1mdeskloop cache clear\u{001B}[0m to free up space.")
            }
            exit(0)
        }

    case .mcp:
        let server = MCPServer(sources: sources)
        server.run()
        exit(0)
    }
} catch {
    print("\u{001B}[31mError:\u{001B}[0m \(error.localizedDescription)")
    exit(1)
}
