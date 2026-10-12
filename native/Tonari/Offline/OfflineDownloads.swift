import Foundation
import Observation
import TonariCore

/// Downloads the tracks of kept-offline 115 works on a background URLSession,
/// which carries on while the app is suspended or gone. Every pending track
/// is handed over at once: iOS throttles transfers created while the app is
/// in the background (measured 1.8 MB/s against 11.7 MB/s), while ones
/// created in the foreground keep full speed after it leaves. 115 serves
/// them from one CDN host and the session allows one connection per host,
/// so they still run one after another.
@Observable
final class OfflineDownloads {
    static let sessionId = "tonari.offline"
    /// Handed over by the app delegate when the system wakes the app for
    /// finished downloads; called once nothing is left to hand to the session.
    static var backgroundCompletion: (() -> Void)?
    private static let pausedKey = "offline.paused"

    /// Every kept work and how far it has got, oldest first.
    private(set) var entries: [OfflineQueries.Entry] = []
    /// Downloads handed to the session and not finished, by `<work>/<path>`.
    private(set) var submitted: Set<String> = []
    /// Bytes written so far by each running download.
    private(set) var written: [String: Int] = [:]
    /// Set by the user or a failure; kept across launches.
    private(set) var paused = UserDefaults.standard.bool(forKey: pausedKey) {
        didSet { UserDefaults.standard.set(paused, forKey: Self.pausedKey) }
    }
    /// Sources imported from 115, whose works can be kept offline.
    private(set) var p115FolderIds: Set<String> = []

    @ObservationIgnored private let database: AppDatabase
    @ObservationIgnored private let files = OfflineFiles.shared
    @ObservationIgnored private var session: URLSession!
    @ObservationIgnored private var kept: Set<String> = []
    /// Downloads given a fresh link once after theirs expired in the queue.
    @ObservationIgnored private var retried: Set<String> = []
    @ObservationIgnored private var resolving = 0
    @ObservationIgnored private var submittingAll = false
    @ObservationIgnored private var needsSubmit = false
    @ObservationIgnored private var eventsFinished = false

    init(database: AppDatabase) {
        self.database = database
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionId)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = 1
        session = URLSession(configuration: configuration, delegate: SessionDelegate(owner: self), delegateQueue: nil)
        Task {
            // Downloads left running by an earlier launch keep going.
            submitted = Set(await session.allTasks.compactMap(\.taskDescription))
            await database.observe(OfflineQueries.all) { [weak self] in self?.keptChanged($0) }
        }
        Task {
            await database.observe({ try Set(String.fetchAll($0, ImportedFolder.filter(Column("type") == "p115").select(Column("id")))) }) {
                [weak self] in self?.p115FolderIds = $0
            }
        }
    }

    // MARK: - Reading

    var completeWorkIds: Set<String> {
        Set(entries.filter(\.status.isComplete).map(\.id))
    }

    var unfinished: [OfflineQueries.Entry] {
        entries.filter { !$0.status.isComplete }
    }

    func entry(_ workId: String) -> OfflineQueries.Entry? {
        entries.first { $0.id == workId }
    }

    /// Downloaded share of a work by bytes, the running track included.
    func progress(of entry: OfflineQueries.Entry) -> Double {
        let running = written.filter { $0.key.hasPrefix(entry.id + "/") }.values.reduce(0, +)
        return Double(entry.status.downloadedBytes + running) / Double(max(entry.status.totalBytes, 1))
    }

    /// All unfinished works together; nil when there are none.
    var overallProgress: Double? {
        let works = unfinished
        guard !works.isEmpty else { return nil }
        let total = works.reduce(0) { $0 + $1.status.totalBytes }
        let done = works.reduce(0) { $0 + progress(of: $1) * Double($1.status.totalBytes) }
        return done / Double(max(total, 1))
    }

    /// "正在下载 12/38 · 2.1 GB / 7.5 GB" for an unfinished work.
    func progressText(of entry: OfflineQueries.Entry) -> String {
        let status = entry.status
        let done = Int(progress(of: entry) * Double(status.totalBytes))
        let state = paused ? "已暂停" : submitted.contains { $0.hasPrefix(entry.id + "/") } ? "正在下载" : "等待下载"
        return "\(state) \(status.downloaded)/\(status.total) · \(Formatting.bytes(done)) / \(Formatting.bytes(status.totalBytes))"
    }

    /// A track being downloaded now, 0...1; nil when it isn't.
    func fraction(of track: Track) -> Double? {
        written[Self.path(track)].map { Double($0) / Double(max(track.fileSizeBytes, 1)) }
    }

    // MARK: - Actions

    func keep(_ workId: String, folder: [String]) {
        try! database.keepOffline(workId, folder: folder)
    }

    func canKeep(_ work: Work) -> Bool {
        work.importedFolderId.map(p115FolderIds.contains) ?? false
    }

    /// Keeps the folder the work's page would show, for the long-press menu.
    func keep(_ work: Work) {
        let tracks = try! database.reader.read { try WorkQueries.tracks(of: work.productId).fetchAll($0) }
        let tree = WorkTree.build(tracks: tracks, files: [])
        keep(work.productId, folder: TrackFolderMemory.resolve(WorkTree.audioFolders(tree), tree: tree, productId: work.productId)!.path)
    }

    func drop(_ workId: String) {
        try! database.removeOffline(workId)
    }

    func pause() {
        paused = true
        session.getAllTasks { $0.forEach { $0.cancel() } }
    }

    func resume() {
        paused = false
        retried.removeAll()
        submitPending()
    }

    /// Called as the app comes to the foreground, where new downloads get
    /// full speed.
    func becameActive() {
        submitPending()
    }

    // MARK: - Queue

    private static func path(_ track: Track) -> String {
        "\(track.workId)/\(track.relativePath)"
    }

    private func keptChanged(_ works: [OfflineWork]) {
        kept = Set(works.map(\.workId))
        try! files.prune(keeping: kept)
        let kept = kept
        session.getAllTasks { tasks in
            for task in tasks where !kept.contains(String(task.taskDescription!.prefix { $0 != "/" })) {
                task.cancel()
            }
        }
        refresh()
        submitPending()
    }

    private func refresh() {
        entries = try! database.reader.read { try OfflineQueries.entries($0, files: self.files) }
    }

    private func submitPending() {
        guard !submittingAll else {
            needsSubmit = true
            return
        }
        let pending = try! database.reader.read { try OfflineQueries.pending($0, files: files) }
            .filter { !submitted.contains(Self.path($0)) }
        guard !paused, !pending.isEmpty else { return finishBackgroundEvents() }
        submittingAll = true
        Task {
            for track in pending where !paused {
                do {
                    try await submit(track)
                } catch {
                    fail(track, error.localizedDescription)
                }
            }
            submittingAll = false
            if needsSubmit {
                needsSubmit = false
                submitPending()
            } else {
                finishBackgroundEvents()
            }
        }
    }

    private func submit(_ track: Track) async throws {
        resolving += 1
        defer { resolving -= 1 }
        let media = try await P115Client.shared.resolve(pickcode: track.filePath)
        // Paused or dropped while its link was being resolved.
        guard !paused, kept.contains(track.workId) else { return }
        var request = URLRequest(url: media.url)
        for header in media.headers { request.setValue(header.value, forHTTPHeaderField: header.name) }
        let task = session.downloadTask(with: request)
        task.taskDescription = Self.path(track)
        submitted.insert(Self.path(track))
        task.resume()
        DiagnosticLog.shared.write("offline", "download_submit", ["track": Self.path(track)])
    }

    fileprivate func progressed(_ path: String, bytes: Int) {
        if submitted.contains(path) { written[path] = bytes }
    }

    fileprivate func finished(_ path: String, _ outcome: SessionDelegate.Outcome) {
        submitted.remove(path)
        written[path] = nil
        switch outcome {
        case .done, .cancelled:
            refresh()
        case .rejected(let reason):
            let track = try! database.reader.read { try OfflineQueries.track(at: path, $0) }!
            // A link that expired while queued gets one fresh one.
            if !paused && retried.insert(path).inserted {
                // Counted before the task starts, so the background completion waits for it.
                resolving += 1
                Task {
                    do {
                        try await submit(track)
                    } catch {
                        fail(track, error.localizedDescription)
                    }
                    resolving -= 1
                    finishBackgroundEvents()
                }
            } else {
                fail(track, reason)
            }
        case .failed(let reason):
            fail(try! database.reader.read { try OfflineQueries.track(at: path, $0) }!, reason)
        }
        finishBackgroundEvents()
    }

    fileprivate func backgroundEventsDelivered() {
        eventsFinished = true
        finishBackgroundEvents()
    }

    /// The system may suspend the app once told, so it waits until every
    /// link being resolved has been handed to the session.
    private func finishBackgroundEvents() {
        guard eventsFinished, resolving == 0, !submittingAll else { return }
        eventsFinished = false
        Self.backgroundCompletion?()
        Self.backgroundCompletion = nil
    }

    private func fail(_ track: Track, _ reason: String) {
        guard !paused else { return }
        pause()
        DiagnosticLog.shared.write("offline", "download_failed", ["track": Self.path(track), "error": reason])
        let title = try! database.reader.read { try Work.fetchOne($0, key: track.workId)?.displayTitle }
        try! database.logEvent(
            category: "offline", title: "离线下载已暂停", detail: reason,
            productId: track.workId, workTitle: title, action: .resumeDownloads
        )
    }
}

/// Session callbacks arrive on the session's serial queue and go to the
/// main queue in order, so a download's progress and end arrive in order.
private nonisolated final class SessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    enum Outcome: Sendable {
        case done, cancelled
        /// Answered with something other than the file, like an expired link.
        case rejected(String)
        case failed(String)
    }

    private weak var owner: OfflineDownloads?
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
        let path = downloadTask.taskDescription!
        let bytes = Int(totalBytesWritten)
        onMain { $0.progressed(path, bytes: bytes) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        reported[task.taskIdentifier] = nil
        let outcome: Outcome = if let error {
            (error as? URLError)?.code == .cancelled ? .cancelled : .failed(error.localizedDescription)
        } else if let reason = rejected.removeValue(forKey: task.taskIdentifier) {
            .rejected(reason)
        } else {
            .done
        }
        let path = task.taskDescription!
        onMain { $0.finished(path, outcome) }
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
