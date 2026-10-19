import Foundation

public final class FileDownloader: NSObject, Sendable {
    public static let shared = FileDownloader()

    public func download(
        from url: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let delegate = DownloadTaskDelegate(progress: progress)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let tempURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            delegate.continuation = continuation
            let task = session.downloadTask(with: url)
            task.resume()
        }

        let fileManager = FileManager.default
        let parentDir = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        let stagedURL = parentDir.appendingPathComponent(".deskloop-download-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: stagedURL) }
        try fileManager.moveItem(at: tempURL, to: stagedURL)

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: stagedURL)
        } else {
            try fileManager.moveItem(at: stagedURL, to: destination)
        }
    }
}

private final class DownloadTaskDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let progress: @Sendable (Double) -> Void
    var continuation: CheckedContinuation<URL, Error>?
    private let lock = NSLock()

    init(progress: @escaping @Sendable (Double) -> Void) {
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
        if let response = downloadTask.response as? HTTPURLResponse,
           !(1...299).contains(response.statusCode) {
            resume(throwing: URLError(.badServerResponse))
            return
        }
        let tempDestination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: tempDestination)
            resume(returning: tempDestination)
        } catch {
            resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            resume(throwing: error)
        }
    }

    private func resume(returning url: URL) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: url)
    }

    private func resume(throwing error: Error) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(throwing: error)
    }
}
