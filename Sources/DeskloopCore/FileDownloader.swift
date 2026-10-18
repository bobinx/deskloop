import Foundation

public final class FileDownloader: NSObject, Sendable {
    public static let shared = FileDownloader()

    public func download(
        from url: URL,
        to destination: URL,
        progress: @escaping (Double) -> Void
    ) async throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        let delegate = DownloadTaskDelegate(progress: progress)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        let tempURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            delegate.continuation = continuation
            let task = session.downloadTask(with: url)
            task.resume()
        }

        let parentDir = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        session.finishTasksAndInvalidate()
    }
}

private final class DownloadTaskDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let progress: (Double) -> Void
    var continuation: CheckedContinuation<URL, Error>?

    init(progress: @escaping (Double) -> Void) {
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            let pct = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            progress(pct)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let tempDestination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: tempDestination)
            continuation?.resume(returning: tempDestination)
        } catch {
            continuation?.resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
        }
    }
}
