import Foundation

public final class LocalSource: WallpaperSource, Sendable {
    public let name = "local"
    public let description = "Local video files and directories on your Mac (.mp4, .mov, .m4v)"

    public init() {}

    public func fetchFeatured(limit: Int = 20) async throws -> [WallpaperItem] {
        let defaultDirs = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Wallpapers"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/Wallpapers"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".deskloop/cache")
        ]

        var items: [WallpaperItem] = []
        for dir in defaultDirs {
            if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in files {
                    let ext = file.pathExtension.lowercased()
                    if ext == "mp4" || ext == "mov" || ext == "m4v" {
                        items.append(WallpaperItem(
                            id: file.path,
                            title: file.deletingPathExtension().lastPathComponent,
                            sourceName: name,
                            resolution: "Local File",
                            duration: "Video",
                            videoURL: file,
                            thumbnailURL: nil,
                            category: "Local"
                        ))
                    }
                }
            }
        }
        return Array(items.prefix(limit))
    }

    public func search(query: String) async throws -> [WallpaperItem] {
        let all = try await fetchFeatured(limit: 100)
        let q = query.lowercased()
        return all.filter { $0.title.lowercased().contains(q) || $0.id.lowercased().contains(q) }
    }

    public func resolve(id: String) async throws -> WallpaperItem? {
        let expanded = NSString(string: id).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        var values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.isRegularFileKey])
        } catch {
            return nil
        }
        let supportedExtensions = ["mp4", "mov", "m4v"]
        guard values.isRegularFile == true,
              supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return nil
        }
        return WallpaperItem(
            id: url.path,
            title: url.deletingPathExtension().lastPathComponent,
            sourceName: name,
            resolution: "Local File",
            duration: "Video",
            videoURL: url,
            thumbnailURL: nil,
            category: "Local"
        )
    }
}
