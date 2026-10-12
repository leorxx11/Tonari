import Foundation
import Observation
import TonariCore
import UIKit

/// Downloads the tracks of kept-offline 115 works on a background URLSession,
/// which carries on while the app is suspended or gone, from a window of
/// tracks handed over ahead of time.
///
/// iOS throttles tasks created while the app is in the background (measured
/// 1.8 MB/s against 11.7 MB/s), while ones created in the foreground keep full
/// speed after it leaves, and it only wakes the app once every task has
/// finished. So the foreground keeps the window full; once it has run dry in
/// the background, each wake hands over a single track to carry on slowly,
/// and coming back fills the rest of the window beside it.
@Observable
final class OfflineDownloads {
    static let sessionId = "tonari.offline"
    /// Handed over by the app delegate when the system wakes the app for
    /// finished downloads; called once nothing is left to hand to the session.
    static var backgroundCompletion: (() -> Void)?
    private static let pausedKey = "offline.paused"
    /// Fifteen tracks, and at most about 15 minutes at full speed: within the
    /// shortest link seen (32 minutes).
    private static let windowCount = 15
    private static let windowBytes = 10_000_000_000

    /// Every kept work and how far it has got, oldest first.
    private(set) var entries: [OfflineQueries.Entry] = []
    /// Downloads handed to the session and not finished: `<work>/<path>` to
    /// the task carrying it, so the late end of a task cancelled by a pause is
    /// told apart from its successor's.
    private(set) var submitted: [String: Int] = [:]
    /// Bytes written so far by each running download.
    private(set) var written: [String: Int] = [:]
    /// Set by the user or a failure; kept across launches.
    private(set) var paused = UserDefaults.standard.bool(forKey: pausedKey) {
        didSet { UserDefaults.standard.set(paused, forKey: Self.pausedKey) }
    }
    /// Sources imported from 115, whose works can be kept offline.
    private(set) var p115FolderIds: Set<String> = []

    let notifications = DownloadNotifications()
    @ObservationIgnored private let database: AppDatabase
    @ObservationIgnored private let notices: Notices
    @ObservationIgnored private let files = OfflineFiles.shared
    @ObservationIgnored private var session: URLSession!
    @ObservationIgnored private var adoption: Task<Void, Never>!
    @ObservationIgnored private var kept: Set<String> = []
    @ObservationIgnored private var loaded = false
    /// Downloads given a fresh link once after theirs expired in the queue.
    @ObservationIgnored private var retried: Set<String> = []
    /// Tracks whose links are being resolved, taken out of the next refill.
    @ObservationIgnored private var resolving: Set<String> = []
    @ObservationIgnored private var refilling = false
    @ObservationIgnored private var needsRefill = false
    @ObservationIgnored private var eventsFinished = false

    init(database: AppDatabase, notices: Notices) {
        self.database = database
        self.notices = notices
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionId)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = 1
        session = URLSession(configuration: configuration, delegate: SessionDelegate(owner: self), delegateQueue: nil)
        adoption = Task {
            // Downloads left running by an earlier launch keep going.
            for task in await session.allTasks {
                submitted[task.taskDescription!] = task.taskIdentifier
            }
        }
        Task {
            await adoption.value
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
        let state = paused ? "已暂停" : submitted.keys.contains { $0.hasPrefix(entry.id + "/") } ? "正在下载" : "等待下载"
        return "\(state) \(status.downloaded)/\(status.total) · \(Formatting.bytes(done)) / \(Formatting.bytes(status.totalBytes))"
    }

    /// A track being downloaded now, 0...1; nil when it isn't.
    func fraction(of track: Track) -> Double? {
        written[Self.path(track)].map { Double($0) / Double(max(track.fileSizeBytes, 1)) }
    }

    // MARK: - Actions

    func keep(_ workId: String, folder: [String]) {
        notifications.requestAuthorization()
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
        refill()
    }

    /// Called as the app comes to the foreground, where downloads get full speed.
    func becameActive() {
        Task {
            await adoption.value
            refill()
        }
    }

    // MARK: - Queue

    private static func path(_ track: Track) -> String {
        "\(track.workId)/\(track.relativePath)"
    }

    private var isActive: Bool {
        UIApplication.shared.applicationState == .active
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
        refill()
    }

    private func refresh() {
        let before = completeWorkIds
        entries = try! database.reader.read { try OfflineQueries.entries($0, files: self.files) }
        if loaded {
            for entry in entries where entry.status.isComplete && !before.contains(entry.id) {
                announceDone(entry.work)
            }
        }
        loaded = true
    }

    /// Hands over the next tracks while the queue is below its window. A
    /// foreground refill stops once the app leaves, as what it would add
    /// from then on is throttled; in the background the window is a single
    /// track, added only once the queue has run dry.
    private func refill() {
        guard !refilling else {
            needsRefill = true
            return
        }
        let foreground = isActive
        let pending = try! database.reader.read { try OfflineQueries.pending($0, files: files) }
        let queued = pending.filter { submitted[Self.path($0)] != nil }
        let picks = paused ? [] : OfflineWindow.next(
            pending.filter { submitted[Self.path($0)] == nil && !resolving.contains(Self.path($0)) },
            queuedCount: queued.count,
            queuedBytes: queued.reduce(0) { $0 + $1.fileSizeBytes - (written[Self.path($1)] ?? 0) },
            limitCount: foreground ? Self.windowCount : 1, limitBytes: Self.windowBytes
        )
        guard !picks.isEmpty else { return finishBackgroundEvents() }
        DiagnosticLog.shared.write("offline", "window_refill", ["queued": queued.count, "count": picks.count, "foreground": foreground])
        refilling = true
        resolving.formUnion(picks.map(Self.path))
        Task {
            for track in picks {
                if paused || (foreground && !isActive) {
                    resolving.remove(Self.path(track))
                    continue
                }
                await submit(track)
            }
            refilling = false
            if needsRefill {
                needsRefill = false
                refill()
            } else {
                finishBackgroundEvents()
            }
        }
    }

    /// Resolves a track's link and hands it to the session; the track was
    /// put in `resolving` by the caller.
    private func submit(_ track: Track) async {
        let path = Self.path(track)
        defer { resolving.remove(path) }
        do {
            let media = try await P115Client.shared.resolve(pickcode: track.filePath)
            // Paused or dropped while its link was being resolved.
            guard !paused, kept.contains(track.workId) else { return }
            var request = URLRequest(url: media.url)
            for header in media.headers { request.setValue(header.value, forHTTPHeaderField: header.name) }
            let task = session.downloadTask(with: request)
            task.taskDescription = path
            submitted[path] = task.taskIdentifier
            task.resume()
            DiagnosticLog.shared.write("offline", "download_submit", ["track": path, "background": !isActive])
        } catch {
            fail(track, error.localizedDescription)
        }
    }

    fileprivate func progressed(_ path: String, task: Int, bytes: Int) {
        if submitted[path] == task { written[path] = bytes }
    }

    fileprivate func finished(_ path: String, task: Int, _ outcome: SessionDelegate.Outcome) {
        guard submitted[path] == task else { return }
        submitted[path] = nil
        written[path] = nil
        switch outcome {
        case .done, .cancelled:
            refresh()
            refill()
        case .rejected(let reason):
            DiagnosticLog.shared.write("offline", "download_rejected", ["track": path, "reason": reason])
            let track = try! database.reader.read { try OfflineQueries.track(at: path, $0) }!
            // A link that expired while queued gets one fresh one.
            if !paused && retried.insert(path).inserted {
                // Reserved before the task starts, so neither a refill nor
                // the background completion runs ahead of it.
                resolving.insert(path)
                Task {
                    await submit(track)
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
        guard eventsFinished, resolving.isEmpty, !refilling else { return }
        eventsFinished = false
        Self.backgroundCompletion?()
        Self.backgroundCompletion = nil
    }

    // MARK: - Telling the user

    private func announceDone(_ work: Work) {
        if isActive {
            notices.show("《\(work.displayTitle)》已下载完成")
        } else {
            notifications.post(title: "下载完成", body: work.displayTitle, opening: .work(work.productId))
        }
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
        if isActive {
            notices.show("离线下载已暂停：\(reason)", .failure)
        } else {
            notifications.post(title: "离线下载已暂停", body: reason, opening: .messages)
        }
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
        let task = downloadTask.taskIdentifier
        let bytes = Int(totalBytesWritten)
        onMain { $0.progressed(path, task: task, bytes: bytes) }
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
        let id = task.taskIdentifier
        onMain { $0.finished(path, task: id, outcome) }
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
