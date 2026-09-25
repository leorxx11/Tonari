import AVFoundation
import MDKPlayer
import MediaPlayer
import TonariCore
import UIKit

/// The app's video player, an mdk engine beside the audio player. One of
/// the two is "in front" (mini player, lock screen, sleep timer); starting
/// either pauses the other. Videos resume where they were left, saved in
/// the play history the way the Flutter build did.
@Observable
final class VideoController: SleepTarget {
    private(set) var entry: RemoteEntry?
    private(set) var sourceName = ""
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var positionMs = 0
    private(set) var durationMs = 0
    private(set) var rate: Float = 1
    /// Pixel size of the picture, for laying it out at its own ratio.
    private(set) var videoSize: CGSize?
    /// Replaced when a released engine is rebuilt; the surface re-attaches.
    private(set) var engine: MDKPlayer?
    /// Draws the engine's frames; created with it and dropped after it.
    private(set) var renderer: VideoRenderer?
    var errorMessage: String?

    var hasCurrent: Bool { entry != nil }
    var title: String { entry.map { PlaybackStore.fileTitle($0.name) } ?? "" }

    /// Set while this player owns Now Playing and the remote commands.
    @ObservationIgnored var isFront = false
    /// Called before a video starts, so the audio player steps aside.
    @ObservationIgnored var willPlay: (() -> Void)?

    @ObservationIgnored private let store: PlaybackStore
    @ObservationIgnored private let sleep: SleepTimer
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var releaseTask: Task<Void, Never>?
    @ObservationIgnored private var expiresAt: Date?
    /// A video gets one fresh link after failing mid-play.
    @ObservationIgnored private var retried = false
    @ObservationIgnored private var pausedByUser = true
    @ObservationIgnored private var seekingUntil: Date?
    @ObservationIgnored private var lastSave = Date.distantPast
    @ObservationIgnored private var lastStatus: MDKPlayer.MediaStatus = []

    /// Paused in the background this long, the engine is let go (as the
    /// Flutter build did); playing again reopens it where it was.
    private static let releaseAfter: Duration = .seconds(600)

    init(database: AppDatabase, sleep: SleepTimer) {
        store = PlaybackStore(database: database)
        self.sleep = sleep
        observeApp()
        restore()
    }

    /// Brings back the video watched last, paused; nothing opens until play,
    /// since its 115 link has to be fetched anyway.
    private func restore() {
        guard let last = try! store.lastPlayedVideo() else { return }
        entry = last.entry
        sourceName = last.sourceName
        positionMs = last.positionMs
        durationMs = last.durationMs
        DiagnosticLog.shared.write("video", "restore", ["positionMs": positionMs])
    }

    // MARK: - Transport

    func play(_ entry: RemoteEntry, sourceName: String) {
        willPlay?()
        if self.entry?.id == entry.id {
            play()
            return
        }
        saveProgress()
        self.entry = entry
        self.sourceName = sourceName
        try! store.recordVideo(entry, sourceName: sourceName)
        let resume = try! store.videoResumeMs(entry)
        positionMs = resume
        durationMs = 0
        videoSize = nil
        retried = false
        DiagnosticLog.shared.write("video", "play", ["file": entry.name, "resumeMs": resume])
        load(from: resume, andPlay: true)
    }

    func play() {
        willPlay?()
        pausedByUser = false
        releaseTask?.cancel()
        if engine == nil || linkExpiring {
            load(from: positionMs, andPlay: true)
        } else {
            engine!.state = .playing
        }
    }

    func pause() {
        pausedByUser = true
        engine?.state = .paused
        saveProgress()
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func seek(to ms: Int) {
        positionMs = max(0, durationMs > 0 ? min(ms, durationMs) : ms)
        // The clock keeps reporting the old time for a moment after a seek.
        seekingUntil = .now.addingTimeInterval(0.6)
        engine?.seek(toMs: Int64(positionMs))
        // A paused picture still has to show where the seek landed.
        renderer?.isRunning = true
        publishNowPlaying()
    }

    func skip(seconds: Int) {
        seek(to: positionMs + seconds * 1000)
    }

    func setRate(_ rate: Float) {
        self.rate = rate
        engine?.playbackRate = rate
        publishNowPlaying()
    }

    var volume: Float {
        get { engine?.volume ?? 1 }
        set { engine?.volume = newValue }
    }

    /// Ends the video session: progress saved, engine and mini player gone.
    func close() {
        saveProgress()
        loadTask?.cancel()
        clock?.cancel()
        releaseEngine()
        entry = nil
        isPlaying = false
        publishNowPlaying()
    }

    // MARK: - Loading

    private var linkExpiring: Bool {
        expiresAt.map { Date.now > $0.addingTimeInterval(-120) } ?? false
    }

    private func load(from startMs: Int, andPlay: Bool) {
        loadTask?.cancel()
        isLoading = true
        let entry = entry!
        loadTask = Task { [weak self] in
            do {
                let media = try await P115Client.shared.resolve(pickcode: entry.pickcode!)
                try Task.checkCancellation()
                guard let self else { return }
                expiresAt = media.expiresAt
                let engine = engine ?? makeEngine()
                renderer?.isRunning = true
                engine.setHTTPHeaders(media.headers)
                let opened = await engine.open(media.url.absoluteString, from: Int64(startMs))
                try Task.checkCancellation()
                guard opened else { throw P115Error.failed("无法打开视频") }
                durationMs = Int(engine.durationMs)
                videoSize = engine.videoInfo.map { CGSize(width: $0.width, height: $0.height) }
                engine.playbackRate = rate
                isLoading = false
                DiagnosticLog.shared.write("video", "loaded", ["startMs": startMs, "durationMs": durationMs, "codec": engine.videoInfo?.codec ?? "none"])
                if andPlay {
                    pausedByUser = false
                    engine.state = .playing
                }
                publishNowPlaying()
            } catch is CancellationError {
            } catch {
                self?.isLoading = false
                self?.fail(error)
            }
        }
    }

    private func makeEngine() -> MDKPlayer {
        let engine = MDKPlayer()
        engine.setVideoDecoders(["VT", "FFmpeg"])
        engine.onStateChanged { [weak self] state in
            Task { @MainActor in self?.stateChanged(state) }
        }
        engine.onMediaStatus { [weak self] status in
            Task { @MainActor in self?.statusChanged(status) }
        }
        engine.onEvent { event in
            // Which decoder won (VT hardware or FFmpeg software) explains
            // frame rate problems; errors explain the rest.
            guard event.error < 0 || event.category.hasPrefix("decoder") else { return }
            DiagnosticLog.shared.write("video", "engine_event", ["error": event.error, "category": event.category, "detail": event.detail])
        }
        self.engine = engine
        renderer = VideoRenderer(engine: engine)
        return engine
    }

    private func fail(_ error: Error) {
        DiagnosticLog.shared.write("video", "play_error", ["error": "\(error)"])
        errorMessage = error is P115Error ? error.localizedDescription : "无法播放：\(error.localizedDescription)"
    }

    // MARK: - Engine events

    private func stateChanged(_ state: MDKPlayer.State) {
        let playing = state == .playing
        guard playing != isPlaying else { return }
        isPlaying = playing
        // Opening pauses the engine on the way, yet it only settles once a
        // frame has been drawn, so keep drawing while loading.
        renderer?.isRunning = playing || isLoading
        DiagnosticLog.shared.write("video", "state", ["playing": playing, "positionMs": positionMs])
        if playing {
            startClock()
        } else {
            clock?.cancel()
            saveProgress()
            if UIApplication.shared.applicationState == .background { scheduleRelease() }
        }
        publishNowPlaying()
    }

    /// mdk reports the whole status set each time; act on flags as they
    /// appear, not on every later report that still carries them.
    private func statusChanged(_ status: MDKPlayer.MediaStatus) {
        let added = status.subtracting(lastStatus)
        lastStatus = status
        if added.contains(.end) {
            positionMs = durationMs
            saveProgress()
            if sleep.trackCompleted() { pause() }
            pausedByUser = true
        } else if added.contains(.invalid), !isLoading {
            // Mid-play failure: most likely the 115 link expired.
            DiagnosticLog.shared.write("video", "invalid", ["retried": retried, "positionMs": positionMs])
            if !retried {
                retried = true
                load(from: positionMs, andPlay: true)
            } else {
                fail(P115Error.failed("播放中断"))
            }
        }
    }

    private func startClock() {
        clock?.cancel()
        clock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let engine, isPlaying else { return }
        if let seekingUntil, Date.now < seekingUntil { return }
        seekingUntil = nil
        positionMs = Int(engine.positionMs)
        if Date.now.timeIntervalSince(lastSave) > 5 { saveProgress() }
    }

    private func saveProgress() {
        guard let entry, durationMs > 0 else { return }
        lastSave = .now
        try! store.saveFilePosition(positionMs, durationMs: durationMs, of: entry)
    }

    // MARK: - Background

    private func observeApp() {
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.engine != nil, !self.isPlaying else { return }
                self.scheduleRelease()
            }
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.releaseTask?.cancel() }
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            let options = AVAudioSession.InterruptionOptions(rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            MainActor.assumeIsolated {
                guard let self, let engine = self.engine else { return }
                if type == .began, self.isPlaying {
                    engine.state = .paused
                } else if type == .ended, options.contains(.shouldResume), !self.pausedByUser {
                    engine.state = .playing
                }
            }
        }
    }

    private func scheduleRelease() {
        releaseTask?.cancel()
        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: Self.releaseAfter)
            guard !Task.isCancelled, let self, !self.isPlaying else { return }
            DiagnosticLog.shared.write("video", "released", ["positionMs": self.positionMs])
            self.saveProgress()
            self.releaseEngine()
        }
    }

    private func releaseEngine() {
        renderer = nil
        engine = nil
    }

    // MARK: - Lock screen

    func handle(_ command: RemoteCommands.Command) {
        switch command {
        case .play: play()
        case .pause: pause()
        case .toggle: togglePlay()
        case .next, .previous: break
        case .seek(let seconds): seek(to: Int(seconds * 1000))
        }
    }

    func publishNowPlaying() {
        guard isFront else { return }
        let center = MPNowPlayingInfoCenter.default()
        guard hasCurrent else {
            center.nowPlayingInfo = nil
            return
        }
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: sourceName,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
            MPMediaItemPropertyPlaybackDuration: Double(durationMs) / 1000,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(positionMs) / 1000,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(rate),
        ]
        RemoteCommands.update(hasPrevious: false, hasNext: false)
    }
}
