import Foundation

public enum Utilities {
    public static func sanitizeFilename(_ input: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>| ")
        return input.components(separatedBy: invalidCharacters).filter { !$0.isEmpty }.joined(separator: "_")
    }

    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
