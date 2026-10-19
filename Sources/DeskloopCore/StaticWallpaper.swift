import AppKit
import AVFoundation

public enum StaticWallpaperService {
    public static func setDesktopImage(from fileURL: URL) throws {
        var finalImageURL = fileURL

        let ext = fileURL.pathExtension.lowercased()
        if ext == "mp4" || ext == "mov" || ext == "m4v" {
            // Extract first frame
            let staticDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".deskloop/static", isDirectory: true)
            try FileManager.default.createDirectory(at: staticDir, withIntermediateDirectories: true)

            let frameURL = staticDir.appendingPathComponent("static_frame_\(fileURL.lastPathComponent).png")
            try extractFirstFrame(from: fileURL, saveTo: frameURL)
            finalImageURL = frameURL
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            throw NSError(domain: "deskloop", code: 1, userInfo: [NSLocalizedDescriptionKey: "No connected screens found."])
        }

        for screen in screens {
            try NSWorkspace.shared.setDesktopImageURL(finalImageURL, for: screen, options: [:])
        }
    }

    private static func extractFirstFrame(from videoURL: URL, saveTo destination: URL) throws {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "deskloop", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert frame to PNG."])
        }
        try pngData.write(to: destination)
    }
}
