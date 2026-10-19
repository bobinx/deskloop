import Foundation

public enum DeskloopPaths {
    public static var dataDirectory: URL {
        if let directory = ProcessInfo.processInfo.environment["DESKLOOP_HOME"], !directory.isEmpty {
            return URL(fileURLWithPath: directory, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".deskloop", isDirectory: true)
    }
}
