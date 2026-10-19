import XCTest
@testable import DeskloopCore

final class DeskloopTests: XCTestCase {

    func testSanitizeFilename() {
        XCTAssertEqual(Utilities.sanitizeFilename("simple"), "simple")
        XCTAssertEqual(Utilities.sanitizeFilename("Korea and Japan Night"), "Korea_and_Japan_Night")
        XCTAssertEqual(Utilities.sanitizeFilename("folder/file:name?*.mp4"), "folder_file_name_.mp4")
        XCTAssertEqual(Utilities.sanitizeFilename("///trailing///"), "trailing")
        XCTAssertEqual(Utilities.sanitizeFilename("file with   multiple    spaces"), "file_with_multiple_spaces")
    }

    func testFormatBytes() {
        XCTAssertFalse(Utilities.formatBytes(0).isEmpty)
        XCTAssertTrue(Utilities.formatBytes(1024).contains("KB") || Utilities.formatBytes(1024).contains("kB"))
        XCTAssertTrue(Utilities.formatBytes(1024 * 1024 * 50).contains("50") || Utilities.formatBytes(1024 * 1024 * 50).contains("MB"))
    }

    func testEngineStateSerialization() throws {
        let now = Date()
        let original = EngineState(
            pid: 12345,
            videoPath: "/path/to/video.mp4",
            startTime: now,
            executablePath: "/usr/local/bin/deskloop",
            processStartTime: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(EngineState.self, from: data)

        XCTAssertEqual(decoded.pid, 12345)
        XCTAssertEqual(decoded.videoPath, "/path/to/video.mp4")
        XCTAssertEqual(decoded.executablePath, "/usr/local/bin/deskloop")
        XCTAssertEqual(Int(decoded.startTime.timeIntervalSince1970), Int(now.timeIntervalSince1970))
    }

    func testWallpaperItemInitialization() {
        let url = URL(string: "https://example.com/sample.mp4")!
        let item = WallpaperItem(
            id: "test-id",
            title: "Test Wallpaper",
            sourceName: "apple",
            videoURL: url
        )

        XCTAssertEqual(item.id, "test-id")
        XCTAssertEqual(item.title, "Test Wallpaper")
        XCTAssertEqual(item.sourceName, "apple")
        XCTAssertEqual(item.videoURL, url)
        XCTAssertEqual(item.resolution, "4K UHD")
        XCTAssertEqual(item.duration, "Loop")
    }

    func testAppleAerialSourceMetadata() {
        let source = AppleAerialSource()
        XCTAssertEqual(source.name, "apple")
        XCTAssertFalse(source.description.isEmpty)
    }

    func testLocalSourceMetadata() {
        let source = LocalSource()
        XCTAssertEqual(source.name, "local")
        XCTAssertFalse(source.description.isEmpty)
    }

    func testWallpaperItemCodable() throws {
        let item = WallpaperItem(
            id: "codable-test",
            title: "Codable Wallpaper",
            sourceName: "apple",
            resolution: "4K UHD",
            duration: "Loop",
            videoURL: URL(string: "https://example.com/video.mp4")!,
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            category: "Nature"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WallpaperItem.self, from: data)

        XCTAssertEqual(decoded.id, "codable-test")
        XCTAssertEqual(decoded.title, "Codable Wallpaper")
        XCTAssertEqual(decoded.sourceName, "apple")
        XCTAssertEqual(decoded.category, "Nature")
        XCTAssertEqual(decoded.thumbnailURL?.absoluteString, "https://example.com/thumb.jpg")
    }
}
