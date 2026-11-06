import Foundation
import AppKit
import DeskloopCore

let deskloopVersion = "1.2.0"

func printJSONObject(_ dict: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
       let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

func resolveVideoURL(target: String) throws -> URL {
    let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw NSError(domain: "deskloop", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Video path or URL cannot be empty."
        ])
    }

    if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            throw NSError(domain: "deskloop", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid video URL: '\(trimmed)'."
            ])
        }
        return url
    }

    let expanded = NSString(string: trimmed).expandingTildeInPath
    let fileURL = URL(fileURLWithPath: expanded).standardizedFileURL

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
        throw NSError(domain: "deskloop", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Video file not found at: '\(trimmed)'."
        ])
    }

    guard !isDirectory.boolValue else {
        throw NSError(domain: "deskloop", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Expected a video file, but found a directory at: '\(trimmed)'."
        ])
    }

    let ext = fileURL.pathExtension.lowercased()
    let supportedExtensions = ["mp4", "mov", "m4v"]
    guard supportedExtensions.contains(ext) else {
        throw NSError(domain: "deskloop", code: 5, userInfo: [
            NSLocalizedDescriptionKey: "Unsupported video format '.\(ext)'. Please provide an .mp4, .mov, or .m4v file."
        ])
    }

    return fileURL
}

do {
    let command = try CLICommandParser.parse(Array(CommandLine.arguments.dropFirst()))

    switch command {
    case let .help(command):
        print(CLIHelp.text(for: command))
        exit(0)

    case let .version(json):
        if json {
            printJSONObject(["name": "deskloop", "version": deskloopVersion])
        } else {
            print("deskloop version \(deskloopVersion)")
        }
        exit(0)

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

    case let .run(target, isDaemon, json):
        let videoURL = try resolveVideoURL(target: target)

        if isDaemon {
            let state = try EngineProcessController.startDaemon(videoURL: videoURL)
            if json {
                printJSONObject(["status": "running", "pid": state.pid, "video": state.videoPath])
            } else {
                print("Started live wallpaper engine (PID: \(state.pid))")
                print("Video: \(state.videoPath)")
                print("Logs: \(EngineProcessController.logFileURL.path)")
            }
            exit(0)
        } else {
            print("\u{001B}[32mStarting live video wallpaper on all connected displays...\u{001B}[0m")
            print("Video: \(videoURL.isFileURL ? videoURL.path : videoURL.absoluteString)")
            print("Power management active: occlusion auto-pause, low power mode awareness, display sleep hooks.")
            print("Press \u{001B}[1mCtrl+C\u{001B}[0m to stop.")

            let engineLease = try EngineProcessController.acquireEngineLease()
            let signalHandler = ApplicationSignalHandler {
                MainActor.assumeIsolated { WallpaperEngine.shared.stop() }
                do {
                    try EngineProcessController.clearState(ownedBy: getpid())
                } catch {
                    fputs("deskloop: failed to clear engine state: \(error.localizedDescription)\n", stderr)
                }
                NSApplication.shared.terminate(nil)
            }
            MainActor.assumeIsolated { WallpaperEngine.shared.start(with: videoURL) }
            try EngineProcessController.saveState(videoURL: videoURL)
            withExtendedLifetime((signalHandler, engineLease)) {
                NSApplication.shared.run()
            }
        }
    }
} catch {
    if CommandLine.arguments.contains("--json") {
        let failure = error as NSError
        printJSONObject([
            "error": [
                "domain": failure.domain,
                "code": failure.code,
                "message": failure.localizedDescription
            ]
        ])
    } else {
        fputs("deskloop: \(error.localizedDescription)\nRun 'deskloop --help' for usage.\n", stderr)
    }
    exit(1)
}
