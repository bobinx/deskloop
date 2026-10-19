import Foundation

public struct WallpaperItem: Identifiable, Sendable, Codable {
    public let id: String
    public let title: String
    public let sourceName: String
    public let resolution: String
    public let duration: String
    public let videoURL: URL
    public let thumbnailURL: URL?
    public let category: String?

    public init(
        id: String,
        title: String,
        sourceName: String,
        resolution: String = "4K UHD",
        duration: String = "Loop",
        videoURL: URL,
        thumbnailURL: URL? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceName = sourceName
        self.resolution = resolution
        self.duration = duration
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.category = category
    }
}

public protocol WallpaperSource: Sendable {
    var name: String { get }
    var description: String { get }

    func fetchFeatured(limit: Int) async throws -> [WallpaperItem]
    func search(query: String) async throws -> [WallpaperItem]
    func resolve(id: String) async throws -> WallpaperItem?
}
