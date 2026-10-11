import Foundation
import Observation
import TonariCore

/// Downloads the tracks of kept-offline 115 works one at a time on a
/// background URLSession, which carries on while the app is suspended or
/// gone. Each link is resolved right before its download: 115 links expire,
/// so queued ones would go stale.
@Observable
final class OfflineDownloads {
    static let sessionId = "tonari.offline"
    /// Handed over by the app delegate when the system wakes the app for
    /// finished downloads; called once the next download is under way.
    static var backgroundCompletion: (() -> Void)?

    private(set) var current: Track?
    /// The current download, 0...1.
    private(set) var progress = 0.0
    /// Stopped after a failure until the user resumes or the app relaunches.
    private(set) var paused = false
    /// Works with every kept track on the device, for the library badge.
    private(set) var completeWorkIds: Set<String> = []
    /// Bumped whenever a track lands or a work is added or dropped.
    private(set) var revision = 0

    @ObservationIgnored private let database: AppDatabase
    @ObservationIgnored private let files = OfflineFiles.shared
    @ObservationIgnored private var session: URLSession!
    @ObservationIgnored private var kept: Set<String> = []
    @ObservationIgnored private var starting = false
    @ObservationIgnored private var eventsFinished = false

    init(database: AppDatabase) {
        self.database = database
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionId)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        // 115 limits concurrent connections per account.
        configuration.httpMaximumConnectionsPerHost = 1
        session = URLSession(configuration: configuration, delegate: SessionDelegate(owner: self), delegateQueue: nil)
        Task {
            await adoptRunningTask()
            await database.observe(OfflineQueries.all) { [weak self] in self?.keptChanged($0) }
        }
    }

    func keep(_ workId: String, folder: [String]) {
        try! database.keepOffline(workId, folder: folder)
    }

    func drop(_ workId: String) {
        try! database.removeOffline(workId)
    }

    func resume() {
        paused = false
        startNext()
    }

    func status(of workId: String) -> OfflineQueries.Status? {
        try! database.reader.read { try OfflineQueries.status(of: workId, $0, files: files) }
    }

    /// A download left running by an earlier launch keeps going.
    private func adoptRunningTask() async {
        guard let path = await session.allTasks.first?.taskDescription else { return }
        current = try! await database.reader.read { try OfflineQueries.track(at: path, $0) }
    }

    private func keptChanged(_ works: [OfflineWork]) {
        kept = Set(works.map(\.workId))
        try! files.prune(keeping: kept)
        if let current, !kept.contains(current.workId) {
            session.getAllTasks { $0.forEach { $0.cancel() } }
        }
        refresh()
        startNext()
    }

    private func refresh() {
        revision += 1
        completeWorkIds = Set(try! database.reader.read { try OfflineQueries.entries($0, files: self.files) }
            .filter(\.status.isComplete).map(\.id))
    }

    private func startNext() {
        guard current == nil, !starting, !paused else { return finishBackgroundEvents() }
        guard let track = try! database.reader.read({ try OfflineQueries.nextPending($0, files: files) }) else {
            return finishBackgroundEvents()
        }
        starting = true
        current = track
        progress = 0
        Task {
            do {
                let media = try await P115Client.shared.resolve(pickcode: track.filePath)
                // Dropped while its link was being resolved.
                guard kept.contains(track.workId) else {
                    starting = false
                    return completed(nil)
                }
                var request = URLRequest(url: media.url)
                for header in media.headers { request.setValue(header.value, forHTTPHeaderField: header.name) }
                let task = session.downloadTask(with: request)
                task.taskDescription = "\(track.workId)/\(track.relativePath)"
                task.resume()
                DiagnosticLog.shared.write("offline", "download_start", ["track": task.taskDescription!])
            } catch {
                fail(track, error.localizedDescription)
            }
            starting = false
            finishBackgroundEvents()
        }
    }

    fileprivate func progressed(_ fraction: Double) {
        progress = fraction
    }

    fileprivate func completed(_ failure: String?) {
        let track = current
        current = nil
        if let failure, let track {
            fail(track, failure)
        } else {
            refresh()
        }
        startNext()
    }

    fileprivate func backgroundEventsDelivered() {
        eventsFinished = true
        finishBackgroundEvents()
    }

    /// The system may suspend the app once told, so it waits until the
    /// next download has been handed to the session.
    private func finishBackgroundEvents() {
        guard eventsFinished, !starting else { return }
        eventsFinished = false
        Self.backgroundCompletion?()
        Self.backgroundCompletion = nil
    }

    private func fail(_ track: Track, _ reason: String) {
        paused = true
        current = nil
        DiagnosticLog.shared.write("offline", "download_failed", ["track": track.relativePath, "error": reason])
        let title = try! database.reader.read { try Work.fetchOne($0, key: track.workId)?.displayTitle }
        try! database.logEvent(
            category: "offline", title: "离线下载已暂停", detail: reason,
            productId: track.workId, workTitle: title, action: .resumeDownloads
        )
    }
}

/// Session callbacks arrive on the session's serial queue. Each result
/// goes to the main queue in order, so a track's progress, landing and
/// the batch's end are seen in the order they happened.
private nonisolated final class SessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private weak var owner: OfflineDownloads?
    /// Downloads answered with something other than the file, by task.
    private var rejected: [Int: String] = [:]
    private var reported: [Int: Int] = [:]

    init(owner: OfflineDownloads) {
        self.owner = owner
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let status = (downloadTask.response as! HTTPURLResponse).statusCode
        guard status == 200 else {
            rejected[downloadTask.taskIdentifier] = "115 返回 HTTP \(status)"
            return
        }
        do {
            try OfflineFiles.shared.store(location, for: downloadTask.taskDescription!)
        } catch {
            rejected[downloadTask.taskIdentifier] = error.localizedDescription
        }
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let percent = Int(totalBytesWritten * 100 / totalBytesExpectedToWrite)
        guard reported[downloadTask.taskIdentifier] != percent else { return }
        reported[downloadTask.taskIdentifier] = percent
        onMain { $0.progressed(Double(percent) / 100) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        reported[task.taskIdentifier] = nil
        let failure: String? = if let error {
            (error as? URLError)?.code == .cancelled ? nil : error.localizedDescription
        } else {
            rejected.removeValue(forKey: task.taskIdentifier)
        }
        onMain { $0.completed(failure) }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        onMain { $0.backgroundEventsDelivered() }
    }

    private func onMain(_ body: @escaping @MainActor @Sendable (OfflineDownloads) -> Void) {
        DispatchQueue.main.async { [weak owner] in
            MainActor.assumeIsolated {
                if let owner { body(owner) }
            }
        }
    }
}
