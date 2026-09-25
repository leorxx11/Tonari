import Observation

/// Which player is in front: the one the mini player, the lock screen and
/// the sleep timer follow. Starting either brings it forward and pauses
/// the other, so audio and video never play over each other.
@Observable
final class NowPlaying {
    enum Media { case audio, video }

    private(set) var front = Media.audio

    @ObservationIgnored let audio: PlaybackController
    @ObservationIgnored let video: VideoController

    init(audio: PlaybackController, video: VideoController) {
        self.audio = audio
        self.video = video
        if video.hasCurrent {
            front = .video
            audio.isFront = false
            video.isFront = true
            audio.sleep.controller = video
        }
        audio.willPlay = { [weak self] in self?.bring(.audio) }
        video.willPlay = { [weak self] in self?.bring(.video) }
        RemoteCommands.register { [weak self] command in
            guard let self else { return }
            switch self.front {
            case .audio: self.audio.handle(command)
            case .video: self.video.handle(command)
            }
        }
    }

    /// Ends the video and hands the mini player back to audio, paused.
    func closeVideo() {
        video.close()
        bring(.audio)
    }

    private func bring(_ media: Media) {
        guard media != front else { return }
        switch media {
        case .audio: video.pause()
        case .video: audio.pause()
        }
        front = media
        audio.isFront = media == .audio
        video.isFront = media == .video
        audio.sleep.controller = media == .audio ? audio : video
        switch media {
        case .audio: audio.publishNowPlaying()
        case .video: video.publishNowPlaying()
        }
    }
}
