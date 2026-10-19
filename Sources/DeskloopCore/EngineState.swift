import Foundation

public struct EngineState: Codable, Sendable {
    public let pid: Int32
    public let videoPath: String
    public let startTime: Date
    public let executablePath: String
    public let processStartTime: Date

    public init(pid: Int32, videoPath: String, startTime: Date, executablePath: String, processStartTime: Date) {
        self.pid = pid
        self.videoPath = videoPath
        self.startTime = startTime
        self.executablePath = executablePath
        self.processStartTime = processStartTime
    }
}
