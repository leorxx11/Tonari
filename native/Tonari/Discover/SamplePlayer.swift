import AVFoundation
import Observation
import TonariCore

/// Plays a work's chobit preview on the work page: one track after another,
/// nothing on the lock screen, gone when the page goes. Starting it pauses
/// whatever the app was playing.
@Observable
final class SamplePlayer {
    private(set) var tracks: [ChobitSample.Track] = []
    private(set) var current: Int?
    private(set) var isPlaying = false
    /// 0...1 through the current track.
    private(set) var progress = 0.0

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: (any NSObjectProtocol)?

    init() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, let duration = self.player.currentItem?.duration.seconds, duration > 0 else { return }
                self.progress = time.seconds / duration
            }
        }
    }

    /// A fresh copy of the same preview leaves what's playing alone.
    func load(_ sample: ChobitSample) {
        guard sample.tracks != tracks else { return }
        stop()
        tracks = sample.tracks
    }

    /// Plays `index`, or pauses / resumes it when it's the current one.
    func toggle(_ index: Int, pausing audio: PlaybackController, _ video: VideoController) {
        if index == current {
            if isPlaying { pause() } else { resume(pausing: audio, video) }
            return
        }
        audio.pause()
        video.pause()
        start(index)
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        current = nil
        isPlaying = false
        progress = 0
    }

    private func pause() {
        player.pause()
        isPlaying = false
    }

    private func resume(pausing audio: PlaybackController, _ video: VideoController) {
        audio.pause()
        video.pause()
        player.play()
        isPlaying = true
    }

    private func start(_ index: Int) {
        let item = AVPlayerItem(url: tracks[index].url)
        endObserver.map(NotificationCenter.default.removeObserver)
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.finished() }
        }
        player.replaceCurrentItem(with: item)
        current = index
        progress = 0
        player.play()
        isPlaying = true
    }

    /// Goes on to the next track; the last one ends the preview.
    private func finished() {
        guard let current, current + 1 < tracks.count else { return stop() }
        start(current + 1)
    }
}
