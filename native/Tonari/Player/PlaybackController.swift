import AVFoundation
import Combine
import MediaPlayer
import TonariCore
import UIKit

/// The app's single audio player. It outlives every page so the mini player
/// and the lock screen keep working wherever the user goes, and it plays one
/// item at a time: 115 links are resolved per track and expire, so a
/// prebuilt queue would only hold dead URLs.
@Observable
final class PlaybackController {
    /// A work's tracks, or files played straight from a remote browser.
    enum Queue {
        case work(WorkQueue)
        case files([RemoteEntry], sourceName: String)
    }

    private(set) var queue: Queue?
    private(set) var index = 0
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var positionMs = 0 {
        didSet { pip.update(trackId: currentTrack?.id, positionMs: positionMs) }
    }
    private(set) var durationMs = 0
    private(set) var rate: Float = 1
    private(set) var route = AudioRoute.current
    /// A failed play, shown as an alert.
    var errorMessage: String?

    let prefs: PlayerPrefs
    let sleep: SleepTimer
    let pip: SubtitlePiP

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private let store: PlaybackStore
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var scopedFolder: URL?
    /// When the current 115 link stops working.
    @ObservationIgnored private var expiresAt: Date?
    /// Nothing usable is loaded yet: a restored 115 track waits for play.
    @ObservationIgnored private var needsLoad = false
    /// A remote item gets one fresh link after failing mid-play.
    @ObservationIgnored private var retried = false
    /// Set by the user's pause so an interruption ending doesn't resume.
    @ObservationIgnored private var pausedByUser = true
    @ObservationIgnored private var lastListenTick: Date?
    /// While a seek is in flight the clock still reports the old time;
    /// ignore it so the slider doesn't jump back.
    @ObservationIgnored private var seeking = false
    @ObservationIgnored private var seekGeneration = 0
    @ObservationIgnored private var artwork: (workId: String, artwork: MPMediaItemArtwork)?
    @ObservationIgnored private var subscriptions: Set<AnyCancellable> = []

    init(database: AppDatabase) {
        store = PlaybackStore(database: database)
        prefs = PlayerPrefs()
        sleep = SleepTimer(prefs: prefs)
        pip = SubtitlePiP(database: database)
        sleep.controller = self
        pip.player = self
        observePlayer()
        RemoteCommands.register { [weak self] command in self?.handle(command) }
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                self?.tick()
            }
        }
        restore()
    }

    // MARK: - Queue state

    var work: Work? {
        if case .work(let queue) = queue { queue.work } else { nil }
    }

    var currentTrack: Track? {
        if case .work(let queue) = queue { queue.tracks[index] } else { nil }
    }

    var currentFile: RemoteEntry? {
        if case .files(let files, _) = queue { files[index] } else { nil }
    }

    var count: Int {
        switch queue {
        case .work(let queue): queue.tracks.count
        case .files(let files, _): files.count
        case nil: 0
        }
    }

    var hasCurrent: Bool { queue != nil }
    var hasPrevious: Bool { index > 0 }
    var hasNext: Bool { index + 1 < count }

    func title(at index: Int) -> String {
        switch queue! {
        case .work(let queue): queue.tracks[index].titleZh ?? queue.tracks[index].title
        case .files(let files, _): PlaybackStore.fileTitle(files[index].name)
        }
    }

    var title: String { title(at: index) }

    func durationMs(at index: Int) -> Int {
        if case .work(let queue) = queue { queue.tracks[index].durationMs } else { 0 }
    }

    var subtitle: String {
        switch queue! {
        case .work(let queue): queue.work.displayTitle
        case .files(_, let sourceName): sourceName
        }
    }

    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    private var isRemote: Bool {
        switch queue {
        case .work(let queue): queue.source?.type != "local" && queue.source != nil
        case .files: true
        case nil: false
        }
    }

    private var linkExpiring: Bool {
        expiresAt.map { Date.now > $0.addingTimeInterval(-120) } ?? false
    }

    // MARK: - Starting

    /// Plays a work from `index` at `positionMs`. Tapping the track already
    /// playing only resumes it.
    func play(_ workQueue: WorkQueue, at index: Int, from positionMs: Int = 0) {
        if currentTrack?.id == workQueue.tracks[index].id {
            if !isPlaying { play() }
            return
        }
        savePosition()
        if work?.productId != workQueue.work.productId { access(workQueue.source) }
        queue = .work(workQueue)
        self.index = index
        startCurrent(from: positionMs)
    }

    func play(files: [RemoteEntry], at index: Int, sourceName: String) {
        if currentFile?.id == files[index].id {
            if !isPlaying { play() }
            return
        }
        savePosition()
        access(nil)
        queue = .files(files, sourceName: sourceName)
        self.index = index
        startCurrent()
    }

    func play(at index: Int) {
        savePosition()
        self.index = index
        startCurrent()
    }

    private func startCurrent(from startMs: Int = 0) {
        switch queue! {
        case .work(let queue): try! store.trackStarted(queue.tracks[index], of: queue.work)
        case .files(let files, let sourceName): try! store.recordFile(files[index], sourceName: sourceName)
        }
        retried = false
        positionMs = startMs
        durationMs = currentTrack?.durationMs ?? 0
        load(from: startMs, andPlay: true)
    }

    // MARK: - Transport

    func play() {
        pausedByUser = false
        DiagnosticLog.shared.write("player", "play_requested", ["needsLoad": needsLoad, "linkExpiring": linkExpiring])
        if needsLoad || linkExpiring {
            load(from: positionMs, andPlay: true)
        } else {
            player.play()
        }
    }

    func pause() {
        pausedByUser = true
        player.pause()
        savePosition()
    }

    func startSubtitlePiP() {
        pip.start(trackId: currentTrack?.id, positionMs: positionMs)
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func next() {
        if hasNext { play(at: index + 1) }
    }

    func previous() {
        if hasPrevious { play(at: index - 1) }
    }

    func seek(to ms: Int) {
        positionMs = max(0, durationMs > 0 ? min(ms, durationMs) : ms)
        guard !needsLoad else { return }
        seeking = true
        seekGeneration += 1
        let generation = seekGeneration
        DiagnosticLog.shared.write("player", "seek", ["toMs": positionMs])
        player.seek(to: CMTime(value: CMTimeValue(positionMs), timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
                // A newer seek superseded this one and owns the flag.
                guard let self, generation == self.seekGeneration else { return }
                self.seeking = false
                DiagnosticLog.shared.write("player", "seek_done", ["finished": finished, "positionMs": Int(self.player.currentTime().seconds * 1000)])
                self.publishNowPlaying()
            }
        }
    }

    func skip(seconds: Int) {
        seek(to: positionMs + seconds * 1000)
    }

    func setRate(_ rate: Float) {
        self.rate = rate
        player.defaultRate = rate
        if isPlaying { player.rate = rate }
        publishNowPlaying()
    }

    // MARK: - Loading

    private func load(from startMs: Int, andPlay: Bool) {
        loadTask?.cancel()
        isLoading = true
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let asset = try await asset()
                try Task.checkCancellation()
                let item = AVPlayerItem(asset: asset)
                player.replaceCurrentItem(with: item)
                try await ready(item)
                if startMs > 0 {
                    await player.seek(to: CMTime(value: CMTimeValue(startMs), timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
                }
                try Task.checkCancellation()
                learnDuration(item)
                needsLoad = false
                isLoading = false
                DiagnosticLog.shared.write("player", "loaded", ["remote": isRemote, "startMs": startMs, "durationMs": durationMs])
                if andPlay { player.play() }
                publishNowPlaying()
            } catch is CancellationError {
            } catch {
                isLoading = false
                fail(error)
            }
        }
    }

    private func asset() async throws -> AVURLAsset {
        switch queue! {
        case .files(let files, _):
            return try await remoteAsset(pickcode: files[index].pickcode!)
        case .work(let queue):
            let track = queue.tracks[index]
            switch queue.source?.type {
            case "p115":
                return try await remoteAsset(pickcode: track.filePath)
            case "webdav":
                throw P115Error.failed("暂不支持播放 WebDAV 作品")
            default:
                expiresAt = nil
                return AVURLAsset(url: URL(filePath: track.filePath))
            }
        }
    }

    private func remoteAsset(pickcode: String) async throws -> AVURLAsset {
        let media = try await P115Client.shared.resolve(pickcode: pickcode)
        expiresAt = media.expiresAt
        let headers = Dictionary(media.headers.map { ($0.name, $0.value) }, uniquingKeysWith: { $1 })
        return AVURLAsset(url: media.url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
    }

    /// Combine's `.values` drops a KVO change that lands while the loop body
    /// runs, which lost `readyToPlay` and left loads hanging; a buffered
    /// stream keeps every change.
    private func ready(_ item: AVPlayerItem) async throws {
        let statuses = AsyncStream { continuation in
            let observation = item.observe(\.status, options: [.initial, .new]) { item, _ in continuation.yield(item.status) }
            continuation.onTermination = { _ in observation.invalidate() }
        }
        for await status in statuses {
            switch status {
            case .readyToPlay: return
            case .failed: throw item.error!
            default: continue
            }
        }
        throw CancellationError()
    }

    private func learnDuration(_ item: AVPlayerItem) {
        let seconds = item.duration.seconds
        guard seconds.isFinite, seconds > 0 else { return }
        durationMs = Int(seconds * 1000)
        guard case .work(var workQueue) = queue, workQueue.tracks[index].durationMs == 0 else { return }
        try! store.recordDuration(durationMs, of: workQueue.tracks[index])
        workQueue.tracks[index].durationMs = durationMs
        queue = .work(workQueue)
    }

    private func fail(_ error: Error) {
        DiagnosticLog.shared.write("player", "play_error", ["remote": isRemote, "error": "\(error)"])
        errorMessage = error is P115Error ? error.localizedDescription : "无法播放：\(error.localizedDescription)"
    }

    /// A mid-play failure on a remote item is usually its link expiring;
    /// fetch a fresh one once and carry on from the same spot.
    private func itemFailed(_ error: Error?) {
        DiagnosticLog.shared.write("player", "item_failed", ["retried": retried, "error": "\(error.map { "\($0)" } ?? "nil")"])
        if isRemote && !retried {
            retried = true
            load(from: positionMs, andPlay: true)
        } else {
            fail(error ?? P115Error.failed("播放中断"))
        }
    }

    // MARK: - Completion

    private func trackEnded() {
        if let track = currentTrack { try! store.trackCompleted(track) }
        retried = false
        if sleep.trackCompleted() {
            pause()
            seek(to: 0)
            return
        }
        var generator = SystemRandomNumberGenerator()
        if let next = prefs.mode.indexAfterCompletion(current: index, count: count, using: &generator) {
            play(at: next)
        } else {
            pausedByUser = true
            seek(to: 0)
        }
    }

    // MARK: - Persistence

    private func tick() {
        guard hasCurrent else { return }
        let now = Date.now
        let audible = work != nil && player.timeControlStatus == .playing
        if audible, let last = lastListenTick, let work {
            let ms = Int(now.timeIntervalSince(last) * 1000)
            // A longer gap means the app was suspended; don't guess.
            if ms > 0 && ms <= 15_000 { try! store.addListening(ms, to: work.productId, at: now) }
        }
        lastListenTick = audible ? now : nil
        if isPlaying { savePosition() }
    }

    func savePosition() {
        guard !needsLoad else { return }
        if let track = currentTrack, let work {
            try! store.savePosition(positionMs, of: track, in: work)
        } else if let file = currentFile {
            try! store.saveFilePosition(positionMs, durationMs: durationMs, of: file)
        }
    }

    /// Brings back what was playing last in the mini player, paused where
    /// it was left. 115 links can't be built offline, so those load on play.
    private func restore() {
        switch try! store.lastPlayed() {
        case .work(let workQueue, let index):
            access(workQueue.source)
            queue = .work(workQueue)
            self.index = index
            positionMs = workQueue.tracks[index].lastPositionMs
            durationMs = workQueue.tracks[index].durationMs
        case .file(let file, let sourceName, let positionMs, let durationMs):
            queue = .files([file], sourceName: sourceName)
            index = 0
            self.positionMs = positionMs
            self.durationMs = durationMs
        case nil:
            return
        }
        DiagnosticLog.shared.write("player", "restore", ["remote": isRemote, "file": currentFile != nil, "positionMs": positionMs])
        if isRemote {
            needsLoad = true
            publishNowPlaying()
        } else {
            load(from: positionMs, andPlay: false)
        }
    }

    /// Local works play through their source folder's security scope.
    private func access(_ source: ImportedFolder?) {
        scopedFolder?.stopAccessingSecurityScopedResource()
        scopedFolder = nil
        guard let source, source.type == "local" else { return }
        do {
            let url = try source.scopedURL()
            if url.startAccessingSecurityScopedResource() { scopedFolder = url }
        } catch {
            DiagnosticLog.shared.write("player", "bookmark_unresolved", ["source": source.displayName, "error": "\(error)"])
        }
    }

    // MARK: - Player events

    private func observePlayer() {
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                let playing = status != .paused
                guard playing != isPlaying else { return }
                isPlaying = playing
                pip.playbackStateChanged(isPlaying: playing)
                DiagnosticLog.shared.write("player", "state", ["playing": playing, "positionMs": positionMs])
                if !playing { savePosition() }
                publishNowPlaying()
            }
            .store(in: &subscriptions)

        player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, !self.needsLoad, !self.seeking, time.seconds.isFinite else { return }
                self.positionMs = Int(time.seconds * 1000)
            }
        }

        let center = NotificationCenter.default
        center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] note in
            let item = note.object as? AVPlayerItem
            MainActor.assumeIsolated {
                guard let self, item === self.player.currentItem else { return }
                self.trackEnded()
            }
        }
        center.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] note in
            let item = note.object as? AVPlayerItem
            let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            MainActor.assumeIsolated {
                guard let self, item === self.player.currentItem else { return }
                self.itemFailed(error)
            }
        }
        center.addObserver(forName: AVPlayerItem.playbackStalledNotification, object: nil, queue: .main) { [weak self] note in
            let item = note.object as? AVPlayerItem
            MainActor.assumeIsolated {
                guard let self, item === self.player.currentItem else { return }
                DiagnosticLog.shared.write("player", "stalled", ["linkExpired": self.expiresAt.map { Date.now > $0 } ?? false])
                if let expiresAt = self.expiresAt, Date.now > expiresAt { self.itemFailed(nil) }
            }
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            let options = AVAudioSession.InterruptionOptions(rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            MainActor.assumeIsolated {
                guard let self else { return }
                DiagnosticLog.shared.write("player", "interruption", ["type": "\(type.map { "\($0.rawValue)" } ?? "?")", "shouldResume": options.contains(.shouldResume)])
                if type == .ended && options.contains(.shouldResume) && !self.pausedByUser && self.hasCurrent {
                    self.player.play()
                }
            }
        }
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
            MainActor.assumeIsolated {
                let route = AudioRoute.current
                DiagnosticLog.shared.write("player", "route_change", ["reason": reason, "output": route.name ?? "iPhone"])
                self?.route = route
            }
        }
    }

    // MARK: - Lock screen

    private func handle(_ command: RemoteCommands.Command) {
        switch command {
        case .play: play()
        case .pause: pause()
        case .toggle: togglePlay()
        case .next: next()
        case .previous: previous()
        case .seek(let seconds): seek(to: Int(seconds * 1000))
        }
    }

    private func publishNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard hasCurrent else {
            center.nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: subtitle,
            MPMediaItemPropertyAlbumTitle: work?.productId ?? subtitle,
            MPMediaItemPropertyPlaybackDuration: Double(durationMs) / 1000,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(positionMs) / 1000,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(rate),
        ]
        if let work, let artwork, artwork.workId == work.productId {
            info[MPMediaItemPropertyArtwork] = artwork.artwork
        } else if let work, let path = work.mainImageLocalPath {
            loadArtwork(workId: work.productId, path: path)
        }
        center.nowPlayingInfo = info
        RemoteCommands.update(hasPrevious: hasPrevious, hasNext: hasNext)
    }

    private func loadArtwork(workId: String, path: String) {
        Task {
            guard let image = await ThumbnailCache.shared.image(path: path, size: CGSize(width: 600, height: 600), scale: 1) else { return }
            artwork = (workId, RemoteCommands.artwork(image))
            publishNowPlaying()
        }
    }
}

/// Lock screen / Control Center / headphone commands. MediaPlayer calls
/// these handlers off the main actor, so they are built nonisolated and hop
/// back before touching the player.
enum RemoteCommands {
    enum Command: Sendable {
        case play, pause, toggle, next, previous
        case seek(Double)
    }

    nonisolated static func register(_ handler: @escaping @MainActor (Command) -> Void) {
        let center = MPRemoteCommandCenter.shared()
        func on(_ command: MPRemoteCommand, _ value: @escaping @Sendable (MPRemoteCommandEvent) -> Command) {
            command.addTarget { event in
                let command = value(event)
                Task { @MainActor in handler(command) }
                return .success
            }
        }
        on(center.playCommand) { _ in .play }
        on(center.pauseCommand) { _ in .pause }
        on(center.togglePlayPauseCommand) { _ in .toggle }
        on(center.nextTrackCommand) { _ in .next }
        on(center.previousTrackCommand) { _ in .previous }
        on(center.changePlaybackPositionCommand) { .seek(($0 as! MPChangePlaybackPositionCommandEvent).positionTime) }
    }

    static func update(hasPrevious: Bool, hasNext: Bool) {
        let center = MPRemoteCommandCenter.shared()
        center.previousTrackCommand.isEnabled = hasPrevious
        center.nextTrackCommand.isEnabled = hasNext
    }

    nonisolated static func artwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
