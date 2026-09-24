import Foundation

/// Pauses playback after a countdown or after a number of tracks. The last
/// ten seconds of a countdown fade out, unless the track may finish first.
@Observable
final class SleepTimer {
    static let presetMinutes = [15, 30, 45, 60, 90]
    static let presetTrackCounts = [1, 2, 3, 5]
    private static let fadeSeconds = 10

    /// Seconds left in a countdown.
    private(set) var remaining: Int?
    /// Stop once this many tracks finish (1 = the current one).
    private(set) var remainingTracks: Int?
    /// The countdown ended but the current track is allowed to finish.
    private(set) var waitingTrackEnd = false

    var isActive: Bool { remaining != nil || remainingTracks != nil || waitingTrackEnd }

    /// `播完本曲停` style suffix for the player's subtitle line.
    var statusText: String? {
        if let remaining { return "定时 \(Formatting.trackTime(ms: remaining * 1000))" }
        if waitingTrackEnd || remainingTracks == 1 { return "播完本曲停" }
        if let remainingTracks { return "还剩 \(remainingTracks) 曲停" }
        return nil
    }

    @ObservationIgnored weak var controller: PlaybackController?
    private let prefs: PlayerPrefs
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var fadeBase: Float?

    init(prefs: PlayerPrefs) {
        self.prefs = prefs
    }

    func start(seconds: Int) {
        reset()
        remaining = seconds
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    func stopAfter(tracks: Int) {
        reset()
        remainingTracks = tracks
    }

    func cancel() {
        reset()
    }

    /// Called when a track finishes on its own; true means pause now.
    func trackCompleted() -> Bool {
        if waitingTrackEnd {
            reset()
            return true
        }
        guard let tracks = remainingTracks else { return false }
        if tracks > 1 {
            remainingTracks = tracks - 1
            return false
        }
        reset()
        return true
    }

    private func tick() {
        guard let controller, let current = remaining else { return }
        let next = current - 1
        guard next > 0 else {
            fire(controller)
            return
        }
        remaining = next
        if next <= Self.fadeSeconds && !prefs.sleepFinishCurrentTrack {
            let base = fadeBase ?? controller.volume
            fadeBase = base
            controller.volume = base * Float(next) / Float(Self.fadeSeconds)
        }
    }

    private func fire(_ controller: PlaybackController) {
        let finishTrack = prefs.sleepFinishCurrentTrack && controller.isPlaying
        reset()
        if finishTrack {
            waitingTrackEnd = true
        } else {
            controller.pause()
        }
    }

    private func reset() {
        ticker?.cancel()
        ticker = nil
        remaining = nil
        remainingTracks = nil
        waitingTrackEnd = false
        if let fadeBase {
            controller?.volume = fadeBase
            self.fadeBase = nil
        }
    }
}
