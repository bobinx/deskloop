import XCTest
@testable import DeskloopCore

final class DeskloopTests: XCTestCase {

    func testEngineStatePreservesProcessIdentityInPersistedJSON() throws {
        let started = Date(timeIntervalSince1970: 1_700_000_000.123456)
        let original = EngineState(
            pid: 12345,
            videoPath: "/path/to/video.mp4",
            startTime: Date(timeIntervalSince1970: 1_700_000_010),
            executablePath: "/usr/local/bin/deskloop",
            processStartTime: started
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EngineState.self, from: data)

        XCTAssertEqual(decoded.pid, original.pid)
        XCTAssertEqual(decoded.videoPath, original.videoPath)
        XCTAssertEqual(decoded.executablePath, original.executablePath)
        XCTAssertEqual(decoded.startTime, original.startTime)
        XCTAssertEqual(decoded.processStartTime, started)
    }

    func testDeskloopPathsRespectsEnvironmentOverride() {
        let customHome = "/tmp/deskloop-custom-home-\(UUID().uuidString)"
        setenv("DESKLOOP_HOME", customHome, 1)
        defer { unsetenv("DESKLOOP_HOME") }

        XCTAssertEqual(DeskloopPaths.dataDirectory.path, customHome)
    }
}
