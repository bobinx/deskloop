import Darwin
import Dispatch
import Foundation
import DeskloopCore

enum EngineProcessController {
    static let appDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".deskloop", isDirectory: true)
    }()

    static let stateFileURL = appDirectory.appendingPathComponent("live.json")
    static let logFileURL = appDirectory.appendingPathComponent("live.log")
    private static let lockFileURL = appDirectory.appendingPathComponent("engine.lock")

    static func saveState(videoURL: URL) throws {
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        let executablePath = (Bundle.main.executablePath ?? CommandLine.arguments[0])
        let state = EngineState(
            pid: getpid(),
            videoPath: videoURL.isFileURL ? videoURL.path : videoURL.absoluteString,
            startTime: Date(),
            executablePath: URL(fileURLWithPath: executablePath).standardizedFileURL.path,
            processStartTime: try processStartTime(pid: getpid())
        )
        let data = try JSONEncoder().encode(state)
        try data.write(to: stateFileURL, options: .atomic)
    }

    static func loadState() throws -> EngineState? {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else { return nil }
        let data = try Data(contentsOf: stateFileURL)
        return try JSONDecoder().decode(EngineState.self, from: data)
    }

    static func acquireEngineLease() throws -> EngineProcessLease {
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        let lease = try EngineProcessLease(lockFileURL: lockFileURL)
        guard let state = try loadState() else { return lease }
        if isRecordedProcess(state) {
            throw NSError(
                domain: "deskloop",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "A live wallpaper engine is already running (PID: \(state.pid)). Run 'deskloop stop' before applying another wallpaper."]
            )
        }
        try clearState(ownedBy: state.pid)
        return lease
    }

    static func stopRunningEngine() throws -> (success: Bool, message: String) {
        guard let state = try loadState() else {
            return (false, "No running live wallpaper engine recorded.")
        }
        guard isRecordedProcess(state) else {
            try clearState(ownedBy: state.pid)
            return (false, "Cleaned up stale wallpaper process record (PID: \(state.pid)).")
        }
        guard kill(state.pid, SIGTERM) == 0 else {
            throw NSError(domain: "deskloop", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not stop live wallpaper engine (PID: \(state.pid))."])
        }
        for _ in 0..<20 {
            usleep(100_000)
            guard isRecordedProcess(state) else {
                try clearState(ownedBy: state.pid)
                return (true, "Stopped live wallpaper engine (PID: \(state.pid)).")
            }
        }
        return (false, "Live wallpaper engine (PID: \(state.pid)) did not stop within two seconds.")
    }

    static func clearState(ownedBy pid: Int32) throws {
        guard try loadState()?.pid == pid else { return }
        try FileManager.default.removeItem(at: stateFileURL)
    }

    static func isRunning(_ state: EngineState) -> Bool {
        isRecordedProcess(state)
    }

    private static func isRecordedProcess(_ state: EngineState) -> Bool {
        guard state.pid > 0, kill(state.pid, 0) == 0,
              let executable = executablePath(pid: state.pid),
              executable == state.executablePath,
              let started = try? processStartTime(pid: state.pid) else { return false }
        return started == state.processStartTime
    }

    private static func executablePath(pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX * 4))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: buffer)).standardizedFileURL.path
    }

    private static func processStartTime(pid: Int32) throws -> Date {
        var processInfo = proc_bsdinfo()
        let bytesRead = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &processInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
        guard bytesRead == Int32(MemoryLayout<proc_bsdinfo>.size) else {
            throw NSError(domain: "deskloop", code: 7, userInfo: [NSLocalizedDescriptionKey: "Could not read process identity for PID \(pid)."])
        }
        let seconds = TimeInterval(processInfo.pbi_start_tvsec)
        let microseconds = TimeInterval(processInfo.pbi_start_tvusec) / 1_000_000
        return Date(timeIntervalSince1970: seconds + microseconds)
    }
}

final class EngineProcessLease {
    private let fileHandle: FileHandle

    init(lockFileURL: URL) throws {
        let descriptor = open(lockFileURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not open the wallpaper engine lock file."])
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let lockError = errno
            close(descriptor)
            let message = lockError == EWOULDBLOCK
                ? "A live wallpaper engine is already starting or running."
                : "Could not acquire the wallpaper engine lock."
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(lockError), userInfo: [NSLocalizedDescriptionKey: message])
        }
        fileHandle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }
}

final class ApplicationSignalHandler {
    private var sources: [DispatchSourceSignal] = []

    init(onTermination: @escaping () -> Void) {
        for signalNumber in [SIGINT, SIGTERM] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler(handler: onTermination)
            source.resume()
            sources.append(source)
        }
    }
}
