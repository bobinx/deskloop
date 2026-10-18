import Foundation
import AppKit
import DeskloopCore

let deskloopVersion = "1.0.0"

func printUsage() {
    print("""
    \u{001B}[1;36mdeskloop\u{001B}[0m v\(deskloopVersion) - Native Live Wallpaper Engine for macOS

    \u{001B}[1mUSAGE:\u{001B}[0m
        deskloop <command> [options]

    \u{001B}[1mCOMMANDS:\u{001B}[0m
        \u{001B}[32mapply\u{001B}[0m, \u{001B}[32mlive\u{001B}[0m <id|path|url> [--daemon] Apply live video wallpaper across all displays
        \u{001B}[32mstatus\u{001B}[0m                                  Check running wallpaper engine status
        \u{001B}[32mstop\u{001B}[0m                                    Stop running live wallpaper daemon
        \u{001B}[32mfeatured\u{001B}[0m [limit]                       Browse featured 4K wallpapers
        \u{001B}[32msearch\u{001B}[0m <query>                         Search wallpapers by keyword
        \u{001B}[32mdownload\u{001B}[0m <id> [-o path]                 Download video wallpaper to local disk
        \u{001B}[32mset-static\u{001B}[0m <id|path|url>               Set first frame as native static desktop wallpaper
        \u{001B}[32msources\u{001B}[0m                                List available wallpaper sources
        \u{001B}[32mcache\u{001B}[0m [list|clear]                      Manage downloaded wallpaper cache

    \u{001B}[1mOPTIONS:\u{001B}[0m
        \u{001B}[33m--source <name>\u{001B}[0m                       Select source: \u{001B}[1mapple\u{001B}[0m (default) or \u{001B}[1mlocal\u{001B}[0m
        \u{001B}[33m--daemon\u{001B}[0m                              Run silently in the background
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
        deskloop search "Greenland"
        deskloop apply "Korea and Japan Night" --daemon
        deskloop apply ~/Movies/wallpaper.mp4 --daemon
        deskloop status
        deskloop stop
        deskloop cache clear
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

func parseCommandLineArgs(_ args: [String]) -> (source: WallpaperSource?, cleanArgs: [String], error: String?) {
    let sources = getRegisteredSources()
    var filtered: [String] = []
    var chosenName: String? = nil

    var skipNext = false
    for (i, arg) in args.enumerated() {
        if skipNext {
            skipNext = false
            continue
        }
        if arg == "--source" {
            if i + 1 < args.count {
                chosenName = args[i + 1].lowercased()
                skipNext = true
            } else {
                return (nil, [], "Missing argument for --source.")
            }
        } else {
            filtered.append(arg)
        }
    }

    if let name = chosenName {
        guard let source = sources[name] else {
            let available = sources.keys.sorted().joined(separator: ", ")
            return (nil, [], "Unknown source '\(name)'. Available sources: \(available).")
        }
        return (source, filtered, nil)
    }

    return (sources["apple"]!, filtered, nil)
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

func runAsync<T>(_ block: @escaping () async throws -> T) throws -> T {
    var result: Result<T, Error>?
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        do {
            let val = try await block()
            result = .success(val)
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    switch result! {
    case .success(let val): return val
    case .failure(let err): throw err
    }
}

func formatBytes(_ bytes: Int64) -> String {
    return Utilities.formatBytes(bytes)
}

func sanitizeFilename(_ input: String) -> String {
    return Utilities.sanitizeFilename(input)
}

func resolveVideoURL(target: String, source: WallpaperSource) throws -> URL {
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

    let cacheDir = WallpaperEngine.appDir.appendingPathComponent("cache", isDirectory: true)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

    let safeTarget = sanitizeFilename(target)
    let cacheFileName = "\(source.name)_\(safeTarget).mp4"
    let localCache = cacheDir.appendingPathComponent(cacheFileName)

    if FileManager.default.fileExists(atPath: localCache.path) {
        return localCache
    }

    print("Resolving '\(target)' from source [\(source.name)]...")
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

    print("Downloading \"\(item.title)\"...")
    try runAsync {
        try await FileDownloader.shared.download(from: item.videoURL, to: localCache) { progress in
            let percent = Int(progress * 100)
            let barLength = 30
            let filled = Int(progress * Double(barLength))
            let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: max(0, barLength - filled))
            print("\r[\(bar)] \(percent)%", terminator: "")
            fflush(stdout)
        }
    }
    print("\nDownload complete.")
    return localCache
}

let rawArgs = CommandLine.arguments

guard rawArgs.count > 1 else {
    printUsage()
    exit(0)
}

let firstArg = rawArgs[1].lowercased()
if firstArg == "-h" || firstArg == "--help" || firstArg == "help" {
    printUsage()
    exit(0)
}

if firstArg == "-v" || firstArg == "--version" || firstArg == "version" {
    print("deskloop version \(deskloopVersion)")
    exit(0)
}

let (parsedSource, cleanArgs, parseError) = parseCommandLineArgs(rawArgs)
if let err = parseError {
    print("\u{001B}[31mError:\u{001B}[0m \(err)")
    exit(1)
}

guard let source = parsedSource, cleanArgs.count > 1 else {
    printUsage()
    exit(0)
}

let command = cleanArgs[1].lowercased()

do {
    switch command {
    case "sources":
        let all = getRegisteredSources()
        let rows = all.values.sorted(by: { $0.name < $1.name }).map { [$0.name, $0.description] }
        print("\n\u{001B}[1;32mAvailable Wallpaper Sources:\u{001B}[0m")
        formatTable(rows, headers: ["Source Name", "Description"])
        exit(0)

    case "featured", "trending", "list":
        let limit = cleanArgs.count > 2 ? Int(cleanArgs[2]) ?? 15 : 15
        let items = try runAsync { try await source.fetchFeatured(limit: limit) }
        let rows = items.map { [
            $0.id,
            $0.title,
            $0.category ?? "N/A",
            $0.resolution,
            $0.duration
        ] }
        print("\n\u{001B}[1;32mFeatured Wallpapers (Source: \(source.name)):\u{001B}[0m (\(items.count) items)")
        formatTable(rows, headers: ["ID", "Title", "Category", "Resolution", "Duration"])
        exit(0)

    case "search":
        guard cleanArgs.count > 2 else {
            print("\u{001B}[31mError:\u{001B}[0m Missing search query. Usage: deskloop search <query> [--source apple|local]")
            exit(1)
        }
        let query = cleanArgs[2...].joined(separator: " ")
        print("Searching [\(source.name)] for: \"\(query)\"...")
        let results = try runAsync { try await source.search(query: query) }
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
        print("\n\u{001B}[1;32mSearch Results (\(source.name)):\u{001B}[0m (\(results.count) found)")
        formatTable(rows, headers: ["ID", "Title", "Category", "Resolution", "Duration"])
        exit(0)

    case "download":
        guard cleanArgs.count > 2 else {
            print("\u{001B}[31mError:\u{001B}[0m Missing ID. Usage: deskloop download <id> [-o output.mp4] [--source ...]")
            exit(1)
        }
        let targetId = cleanArgs[2]
        var outputPath = "wallpaper_\(sanitizeFilename(targetId)).mp4"
        if cleanArgs.count >= 5 && cleanArgs[3] == "-o" {
            outputPath = cleanArgs[4]
        } else if cleanArgs.count >= 4 && !cleanArgs[3].starts(with: "-") {
            outputPath = cleanArgs[3]
        }

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

    case "apply", "live":
        guard cleanArgs.count > 2 else {
            print("\u{001B}[31mError:\u{001B}[0m Missing ID, URL, or video path. Usage: deskloop apply <id|path|url> [--daemon] [--source ...]")
            exit(1)
        }
        let target = cleanArgs[2]
        let isDaemon = cleanArgs.contains("--daemon")

        let videoURL = try resolveVideoURL(target: target, source: source)

        if isDaemon {
            let executablePath: String
            if let path = Bundle.main.executablePath, FileManager.default.fileExists(atPath: path) {
                executablePath = path
            } else {
                executablePath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
            }

            let logFile = WallpaperEngine.logFileURL
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
            let logHandle = try FileHandle(forWritingTo: logFile)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = ["apply", videoURL.path]
            process.standardOutput = logHandle
            process.standardError = logHandle
            try process.run()

            print("\u{001B}[32mStarted live wallpaper daemon (PID: \(process.processIdentifier))\u{001B}[0m")
            print("Video: \(videoURL.path)")
            print("Logs: \(logFile.path)")
            print("Run \u{001B}[1mdeskloop status\u{001B}[0m or \u{001B}[1mdeskloop stop\u{001B}[0m to manage.")
            exit(0)
        } else {
            print("\u{001B}[32mStarting live video wallpaper on all connected displays...\u{001B}[0m")
            print("Video: \(videoURL.path)")
            print("Power management active: occlusion auto-pause, low power mode awareness, display sleep hooks.")
            print("Press \u{001B}[1mCtrl+C\u{001B}[0m to stop.")

            WallpaperEngine.shared.start(with: videoURL)
            NSApplication.shared.run()
        }

    case "status":
        guard let state = WallpaperEngine.loadState() else {
            print("Status: \u{001B}[33mStopped\u{001B}[0m (No live wallpaper engine running)")
            exit(0)
        }

        let isRunning = WallpaperEngine.isProcessRunning(pid: state.pid)
        if !isRunning {
            WallpaperEngine.clearState()
            print("Status: \u{001B}[33mStopped\u{001B}[0m (Cleaned up stale process record PID \(state.pid))")
            exit(0)
        }

        let screenCount = NSScreen.screens.count
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let uptimeString = formatter.localizedString(for: state.startTime, relativeTo: Date())

        print("""
        Status:          \u{001B}[32mRunning\u{001B}[0m
        Process ID:      \(state.pid)
        Active Video:    \(state.videoPath)
        Started:         \(uptimeString)
        Active Displays: \(screenCount) connected display\(screenCount == 1 ? "" : "s")
        Log File:        \(WallpaperEngine.logFileURL.path)
        """)
        exit(0)

    case "stop":
        let result = WallpaperEngine.stopRunningEngine()
        if result.success {
            print("\u{001B}[32m\(result.message)\u{001B}[0m")
        } else {
            print(result.message)
        }
        exit(0)

    case "set-static":
        guard cleanArgs.count > 2 else {
            print("\u{001B}[31mError:\u{001B}[0m Missing ID, URL, or video path. Usage: deskloop set-static <id|path|url> [--source ...]")
            exit(1)
        }
        let target = cleanArgs[2]
        let fileURL = try resolveVideoURL(target: target, source: source)

        print("Setting static wallpaper for all displays...")
        try StaticWallpaperService.setDesktopImage(from: fileURL)
        print("\u{001B}[32mSuccessfully updated desktop wallpaper.\u{001B}[0m")
        exit(0)

    case "cache":
        let cacheDir = WallpaperEngine.appDir.appendingPathComponent("cache", isDirectory: true)
        let subaction = cleanArgs.count > 2 ? cleanArgs[2].lowercased() : "list"

        switch subaction {
        case "clear", "clean", "purge":
            guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else {
                print("Cache directory is empty.")
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
            print("\u{001B}[32mCleared \(deletedCount) cached video\(deletedCount == 1 ? "" : "s") (\(formatBytes(freedBytes)) freed).\u{001B}[0m")
            exit(0)

        case "list", "ls":
            guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else {
                print("Cache is empty.")
                exit(0)
            }
            let videoFiles = files.filter { $0.pathExtension.lowercased() == "mp4" || $0.pathExtension.lowercased() == "mov" }
            if videoFiles.isEmpty {
                print("Cache is empty (no downloaded videos in \(cacheDir.path)).")
                exit(0)
            }

            var totalBytes: Int64 = 0
            var rows: [[String]] = []
            for file in videoFiles {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                totalBytes += Int64(size)
                rows.append([file.lastPathComponent, formatBytes(Int64(size))])
            }

            print("\n\u{001B}[1;32mCached Video Wallpapers (\(cacheDir.path)):\u{001B}[0m")
            formatTable(rows, headers: ["File Name", "Size"])
            print("\nTotal disk usage: \u{001B}[1m\(formatBytes(totalBytes))\u{001B}[0m across \(videoFiles.count) file\(videoFiles.count == 1 ? "" : "s").")
            print("Run \u{001B}[1mdeskloop cache clear\u{001B}[0m to free up space.")
            exit(0)

        default:
            print("\u{001B}[31mUnknown cache command:\u{001B}[0m \(subaction). Available options: list, clear")
            exit(1)
        }

    default:
        print("\u{001B}[31mUnknown command:\u{001B}[0m \(command)\n")
        printUsage()
        exit(1)
    }
} catch {
    print("\u{001B}[31mError:\u{001B}[0m \(error.localizedDescription)")
    exit(1)
}
