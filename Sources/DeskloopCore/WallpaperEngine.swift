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

@MainActor
public final class WallpaperEngine: NSObject {
    public static let shared = WallpaperEngine()

    @MainActor
    private final class ScreenEntry {
        let window: NSWindow
        let player: AVQueuePlayer
        let looper: AVPlayerLooper
        var occlusionObserver: NSObjectProtocol?
        var isOccluded: Bool = false
        var failureObservation: PlaybackFailureObservation?

        init(window: NSWindow, player: AVQueuePlayer, looper: AVPlayerLooper) {
            self.window = window
            self.player = player
            self.looper = looper
        }
    }

    private var entries: [ScreenEntry] = []
    private var videoURL: URL?
    private var systemObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    private var suspensionReasons: PlaybackSuspensionReasons = []

    public func start(with url: URL) {
        self.videoURL = url
        NSApplication.shared.setActivationPolicy(.accessory)

        setupPowerAndSystemObservers()
        setupWindows()
    }

    private func setupPowerAndSystemObservers() {
        systemObservers.forEach { NotificationCenter.default.removeObserver($0) }
        systemObservers.removeAll()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()

        let ws = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(ws.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.setSuspended(.displaySleep, true)
            }
        })

        workspaceObservers.append(ws.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.setSuspended(.displaySleep, false)
            }
        })

        workspaceObservers.append(ws.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.setSuspended(.systemSleep, true)
            }
        })

        workspaceObservers.append(ws.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.setSuspended(.systemSleep, false)
            }
        })

        systemObservers.append(NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkLowPowerMode()
            }
        })

        systemObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.setupWindows()
            }
        })

        checkLowPowerMode()
    }

    private func checkLowPowerMode() {
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        setSuspended(.lowPowerMode, isLowPower)
    }

    private func setSuspended(_ reason: PlaybackSuspensionReasons, _ suspended: Bool) {
        suspensionReasons.set(reason, suspended: suspended)
        updatePlaybackState()
    }

    private func updatePlaybackState() {
        for entry in entries {
            if suspensionReasons.shouldPause(isOccluded: entry.isOccluded) {
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
                window: window,
                player: queuePlayer,
                looper: looper
            )

            entry.occlusionObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self, weak entry, weak window] _ in
                MainActor.assumeIsolated {
                    guard let self = self, let entry = entry, let win = window else { return }
                    let isVisible = win.occlusionState.contains(.visible)
                    entry.isOccluded = !isVisible
                    self.updatePlaybackState()
                }
            }

            entries.append(entry)
            entry.failureObservation = PlaybackFailureObservation(
                player: queuePlayer, looper: looper, displayID: screenID, videoURL: videoURL
            )

            window.orderFrontRegardless()
        }
        updatePlaybackState()
    }

    public func stop() {
        tearDownWindows()
        systemObservers.forEach { NotificationCenter.default.removeObserver($0) }
        systemObservers.removeAll()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        suspensionReasons = []
        videoURL = nil
    }

    private func tearDownWindows() {
        for entry in entries {
            entry.failureObservation?.invalidate()
            entry.failureObservation = nil
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

@MainActor
final class PlaybackFailureObservation {
    private var observers: [NSKeyValueObservation] = []
    private var itemObserver: NSKeyValueObservation?
    private var isActive = true

    init(
        player: AVQueuePlayer,
        looper: AVPlayerLooper,
        displayID: CGDirectDisplayID,
        videoURL: URL,
        report: @escaping @Sendable (String) -> Void = { FileHandle.standardError.write(Data($0.utf8)) }
    ) {
        observers.append(player.observe(\.status, options: [.initial, .new]) { player, _ in
            guard player.status == .failed else { return }
            Self.reportFailure("player", error: player.error, displayID: displayID, videoURL: videoURL, report: report)
        })
        observers.append(looper.observe(\.status, options: [.initial, .new]) { looper, _ in
            guard looper.status == .failed else { return }
            Self.reportFailure("looper", error: looper.error, displayID: displayID, videoURL: videoURL, report: report)
        })
        observers.append(player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            let currentItem = player.currentItem
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isActive else { return }
                self.itemObserver?.invalidate()
                self.itemObserver = currentItem?.observe(\.status, options: [.initial, .new]) { item, _ in
                    guard item.status == .failed else { return }
                    Self.reportFailure("item", error: item.error, displayID: displayID, videoURL: videoURL, report: report)
                }
            }
        })
    }

    func invalidate() {
        isActive = false
        observers.forEach { $0.invalidate() }
        observers.removeAll()
        itemObserver?.invalidate()
        itemObserver = nil
    }

    nonisolated private static func reportFailure(
        _ component: String,
        error: Error?,
        displayID: CGDirectDisplayID,
        videoURL: URL,
        report: @Sendable (String) -> Void
    ) {
        let detail = error.map { String(describing: $0) } ?? "Unknown playback error"
        let message = "deskloop: \(component) failed on display \(displayID), video \(videoURL.absoluteString): \(detail)\n"
        report(message)
    }

}
