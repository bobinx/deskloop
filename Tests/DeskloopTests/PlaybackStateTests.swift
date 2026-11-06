import XCTest
import AVFoundation
@testable import DeskloopCore

final class PlaybackStateTests: XCTestCase {
    func testSleepWakeSequencesPreserveEveryRemainingReason() {
        let reasons: [PlaybackSuspensionReasons] = [.displaySleep, .systemSleep, .lowPowerMode]
        for first in reasons {
            for second in reasons where second != first {
                var state: PlaybackSuspensionReasons = []
                state.set(first, suspended: true)
                state.set(second, suspended: true)
                state.set(first, suspended: false)
                XCTAssertTrue(state.shouldPause(isOccluded: false))
                state.set(second, suspended: false)
                XCTAssertFalse(state.shouldPause(isOccluded: false))
            }
        }
    }

    func testLowPowerModeRemainsActiveAfterBothWakeEvents() {
        var state: PlaybackSuspensionReasons = [.displaySleep, .systemSleep, .lowPowerMode]
        state.set(.displaySleep, suspended: false)
        state.set(.systemSleep, suspended: false)
        XCTAssertTrue(state.shouldPause(isOccluded: false))
        state.set(.lowPowerMode, suspended: false)
        XCTAssertFalse(state.shouldPause(isOccluded: false))
    }

    func testOcclusionPausesAnOtherwiseActivePlayer() {
        let state: PlaybackSuspensionReasons = []
        XCTAssertTrue(state.shouldPause(isOccluded: true))
        XCTAssertFalse(state.shouldPause(isOccluded: false))
    }

    func testRepeatedNotificationsDoNotAccumulateSuspensions() {
        var state: PlaybackSuspensionReasons = []
        state.set(.displaySleep, suspended: true)
        state.set(.displaySleep, suspended: true)
        XCTAssertTrue(state.shouldPause(isOccluded: false))
        state.set(.displaySleep, suspended: false)
        XCTAssertFalse(state.shouldPause(isOccluded: false))
        state.set(.displaySleep, suspended: false)
        XCTAssertFalse(state.shouldPause(isOccluded: false))
    }

    func testCorruptVideoReportsPlaybackFailureWithoutCreatingWindows() async throws {
        let videoURL = FileManager.default.temporaryDirectory.appendingPathComponent("deskloop-corrupt-\(UUID().uuidString).mp4")
        try Data("This is not a video.".utf8).write(to: videoURL)
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let failure = expectation(description: "AVFoundation reports corrupt video")
        failure.assertForOverFulfill = false
        let playback = await MainActor.run {
            let item = AVPlayerItem(url: videoURL)
            let player = AVQueuePlayer(playerItem: item)
            player.preventsDisplaySleepDuringVideoPlayback = false
            player.isMuted = true
            let looper = AVPlayerLooper(player: player, templateItem: item)
            let observation = PlaybackFailureObservation(
                player: player, looper: looper, displayID: 1234, videoURL: videoURL
            ) { message in
                XCTAssertTrue(message.contains("failed on display 1234"))
                XCTAssertTrue(message.contains(videoURL.absoluteString))
                XCTAssertFalse(message.contains("Unknown playback error"))
                failure.fulfill()
            }
            player.play()
            return (observation, player, looper)
        }

        await fulfillment(of: [failure], timeout: 10)
        await MainActor.run {
            playback.0.invalidate()
            playback.1.pause()
            playback.2.disableLooping()
        }
    }
}
