import Foundation

public final class AppleAerialSource: WallpaperSource, Sendable {
    public let name = "apple"
    public let description = "Official Apple 4K Aerials (Drone, satellite, underwater footage from sylvan.apple.com)"

    private let tarURL = URL(string: "https://sylvan.apple.com/Aerials/resources-16.tar")!
    private let fallbackJSONURL = URL(string: "https://sylvan.apple.com/Aerials/2x/entries.json")!

    private struct AerialAsset: Codable {
        let id: String
        let accessibilityLabel: String?
        let shotID: String?
        let url_4k_sdr: String?
        let url_4k_hdr: String?
        let url_1080_sdr: String?
        let previewImage: String?

        enum CodingKeys: String, CodingKey {
            case id
            case accessibilityLabel
            case shotID
            case url_4k_sdr = "url-4K-SDR"
            case url_4k_hdr = "url-4K-HDR"
            case url_1080_sdr = "url-1080-SDR"
            case previewImage
        }
    }

    private struct AerialManifest: Codable {
        let assets: [AerialAsset]
    }

    public init() {}

    private func cacheDirectory() -> URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".deskloop/cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func loadManifest() async throws -> [AerialAsset] {
        let cacheDir = cacheDirectory()
        let cacheFile = cacheDir.appendingPathComponent("apple_entries.json")

        if let cachedData = try? Data(contentsOf: cacheFile),
           let manifest = try? JSONDecoder().decode(AerialManifest.self, from: cachedData),
           !manifest.assets.isEmpty {
            return manifest.assets.filter { $0.url_4k_sdr != nil || $0.url_4k_hdr != nil }
        }

        // Download Apple resources-16.tar and unpack entries.json
        let tarTemp = cacheDir.appendingPathComponent("resources.tar")
        do {
            let (data, response) = try await URLSession.shared.data(from: tarURL)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                try data.write(to: tarTemp)

                let tarProcess = Process()
                tarProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                tarProcess.arguments = ["-xf", tarTemp.path, "-C", cacheDir.path, "entries.json"]
                try tarProcess.run()
                tarProcess.waitUntilExit()

                try? FileManager.default.removeItem(at: tarTemp)

                let extractedFile = cacheDir.appendingPathComponent("entries.json")
                if FileManager.default.fileExists(atPath: extractedFile.path) {
                    try? FileManager.default.removeItem(at: cacheFile)
                    try FileManager.default.moveItem(at: extractedFile, to: cacheFile)
                }
            }
        } catch {
            // Fall back to direct 2x entries.json if tar fetch fails
            let (data, _) = try await URLSession.shared.data(from: fallbackJSONURL)
            try? data.write(to: cacheFile)
        }

        guard let validData = try? Data(contentsOf: cacheFile) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(AerialManifest.self, from: validData)
        return decoded.assets.filter { $0.url_4k_sdr != nil || $0.url_4k_hdr != nil }
    }

    public func fetchFeatured(limit: Int = 20) async throws -> [WallpaperItem] {
        let assets = try await loadManifest()
        return assets.prefix(limit).compactMap { makeItem(from: $0) }
    }

    public func search(query: String) async throws -> [WallpaperItem] {
        let assets = try await loadManifest()
        let q = query.lowercased()
        let filtered = assets.filter { asset in
            let label = (asset.accessibilityLabel ?? "").lowercased()
            let shot = (asset.shotID ?? "").lowercased()
            let id = asset.id.lowercased()
            return label.contains(q) || shot.contains(q) || id.contains(q)
        }
        return filtered.compactMap { makeItem(from: $0) }
    }

    public func resolve(id: String) async throws -> WallpaperItem? {
        let assets = try await loadManifest()
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let match = assets.first(where: {
            $0.id.lowercased() == cleanId ||
            ($0.accessibilityLabel ?? "").lowercased() == cleanId ||
            ($0.shotID ?? "").lowercased() == cleanId
        }) else {
            return nil
        }
        return makeItem(from: match)
    }

    private func makeItem(from asset: AerialAsset) -> WallpaperItem? {
        guard let urlString = asset.url_4k_sdr ?? asset.url_4k_hdr ?? asset.url_1080_sdr,
              let url = URL(string: urlString) else {
            return nil
        }
        let title = asset.accessibilityLabel ?? asset.shotID ?? "Apple Aerial"
        let thumbURL = asset.previewImage.flatMap { URL(string: $0) }

        return WallpaperItem(
            id: asset.id,
            title: title,
            sourceName: name,
            resolution: asset.url_4k_sdr != nil || asset.url_4k_hdr != nil ? "4K UHD" : "1080p",
            duration: "Aerial Loop",
            videoURL: url,
            thumbnailURL: thumbURL,
            category: "Aerial"
        )
    }
}
