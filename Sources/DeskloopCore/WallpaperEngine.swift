import AppKit
import AVFoundation

final class VideoPlayerHostView: NSView {
    let playerLayer: AVPlayerLayer

    init(player: AVPlayer, frame: NSRect) {
        self.playerLayer = AVPlayerLayer(player: player)
        self.playerLayer.videoGravity = .resizeAspectFill
        self.playerLayer.frame = NSRect(origin: .zero, size: frame.size)
        super.init(frame: frame)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func makeBackingLayer() -> CALayer {
        return playerLayer
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

public struct EngineState: Codable, Sendable {
    public let pid: Int32
    public let videoPath: String
    public let startTime: Date
}

public final class WallpaperEngine: NSObject {
    public static let shared = WallpaperEngine()

    private final class ScreenEntry {
        let displayID: CGDirectDisplayID
        let window: NSWindow
        let player: AVQueuePlayer
        let looper: AVPlayerLooper
        var occlusionObserver: NSObjectProtocol?
        var isOccluded: Bool = false

        init(displayID: CGDirectDisplayID, window: NSWindow, player: AVQueuePlayer, looper: AVPlayerLooper) {
            self.displayID = displayID
            self.window = window
            self.player = player
            self.looper = looper
        }
    }

    private var entries: [ScreenEntry] = []
    private var videoURL: URL?
    private var systemObservers: [NSObjectProtocol] = []

    // Power management state
    private var isPowerSuspended: Bool = false
    private var isSystemSleeping: Bool = false

    public static let appDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".deskloop", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    public static let stateFileURL: URL = {
        return appDir.appendingPathComponent("live.json")
    }()

    public static let pidFileURL: URL = {
        return appDir.appendingPathComponent("live.pid")
    }()

    public static let logFileURL: URL = {
        return appDir.appendingPathComponent("live.log")
    }()

    public static func saveState(videoPath: String) {
        let pid = getpid()
        let state = EngineState(pid: pid, videoPath: videoPath, startTime: Date())
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateFileURL)
        }
        try? String(pid).write(to: pidFileURL, atomically: true, encoding: .utf8)
    }

    public static func loadState() -> EngineState? {
        guard let data = try? Data(contentsOf: stateFileURL),
              let state = try? JSONDecoder().decode(EngineState.self, from: data) else {
            // Fallback to legacy PID file if json not present
            if let pidStr = try? String(contentsOf: pidFileURL, encoding: .utf8),
               let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return EngineState(pid: pid, videoPath: "Unknown", startTime: Date())
            }
            return nil
        }
        return state
    }

    public static func clearState() {
        try? FileManager.default.removeItem(at: stateFileURL)
        try? FileManager.default.removeItem(at: pidFileURL)
    }

    public static func isProcessRunning(pid: Int32) -> Bool {
        return kill(pid, 0) == 0
    }

    public static func stopRunningEngine() -> (success: Bool, message: String) {
        guard let state = loadState() else {
            return (false, "No running live wallpaper engine recorded.")
        }

        guard isProcessRunning(pid: state.pid) else {
            clearState()
            return (false, "Cleaned up stale process record (PID: \(state.pid) was not running).")
        }

        kill(state.pid, SIGTERM)
        // Wait up to 500ms for graceful shutdown
        for _ in 0..<5 {
            usleep(100_000)
            if !isProcessRunning(pid: state.pid) {
                break
            }
        }

        clearState()
        return (true, "Stopped live wallpaper engine (PID: \(state.pid)).")
    }

    public func start(with url: URL) {
        self.videoURL = url
        NSApplication.shared.setActivationPolicy(.accessory)

        WallpaperEngine.saveState(videoPath: url.path)
        setupWindows()
        setupPowerAndSystemObservers()

        signal(SIGINT) { _ in
            WallpaperEngine.shared.stop()
            exit(0)
        }
        signal(SIGTERM) { _ in
            WallpaperEngine.shared.stop()
            exit(0)
        }
    }

    private func setupPowerAndSystemObservers() {
        systemObservers.forEach { NotificationCenter.default.removeObserver($0) }
        systemObservers.removeAll()

        let ws = NSWorkspace.shared.notificationCenter

        // 1. Display and system sleep observers
        systemObservers.append(ws.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setSystemSleeping(true)
        })

        systemObservers.append(ws.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setSystemSleeping(false)
        })

        systemObservers.append(ws.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setSystemSleeping(true)
        })

        systemObservers.append(ws.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setSystemSleeping(false)
        })

        // 2. Low power mode observer
        systemObservers.append(NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkLowPowerMode()
        })

        // 3. Screen layout and resolution change observer
        systemObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupWindows()
        })

        checkLowPowerMode()
    }

    private func checkLowPowerMode() {
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.isPowerSuspended = isLowPower
        updatePlaybackState()
    }

    private func setSystemSleeping(_ sleeping: Bool) {
        self.isSystemSleeping = sleeping
        updatePlaybackState()
    }

    private func updatePlaybackState() {
        for entry in entries {
            if isSystemSleeping || isPowerSuspended || entry.isOccluded {
                entry.player.pause()
            } else {
                entry.player.play()
            }
        }
    }

    private func setupWindows() {
        tearDownWindows()
        guard let videoURL = videoURL else { return }

        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            let window = NSWindow(
                contentRect: screenFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            let desktopLevel = Int(CGWindowLevelForKey(.desktopWindow))
            window.level = NSWindow.Level(desktopLevel)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.backgroundColor = .clear
            window.isOpaque = false
            window.sharingType = .none

            let playerItem = AVPlayerItem(url: videoURL)
            let queuePlayer = AVQueuePlayer(playerItem: playerItem)
            queuePlayer.isMuted = true
            queuePlayer.actionAtItemEnd = .none
            queuePlayer.preventsDisplaySleepDuringVideoPlayback = false

            let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

            let hostView = VideoPlayerHostView(player: queuePlayer, frame: NSRect(origin: .zero, size: screenFrame.size))
            window.contentView = hostView

            let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            let entry = ScreenEntry(
                displayID: screenID,
                window: window,
                player: queuePlayer,
                looper: looper
            )

            // Per-window occlusion observer (properly removed during tearDownWindows)
            entry.occlusionObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self, weak entry, weak window] _ in
                guard let self = self, let entry = entry, let win = window else { return }
                let isVisible = win.occlusionState.contains(.visible)
                entry.isOccluded = !isVisible
                self.updatePlaybackState()
            }

            entries.append(entry)

            window.orderFrontRegardless()
            queuePlayer.play()
        }
    }

    public func stop() {
        tearDownWindows()
        WallpaperEngine.clearState()
    }

    private func tearDownWindows() {
        for entry in entries {
            if let obs = entry.occlusionObserver {
                NotificationCenter.default.removeObserver(obs)
                entry.occlusionObserver = nil
            }
            entry.player.pause()
            entry.window.orderOut(nil)
        }
        entries.removeAll()
    }
}
