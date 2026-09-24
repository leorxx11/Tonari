import Foundation
import MDKPlayer
import MediaPlayer
import Observation
import TonariCore

@Observable
@MainActor
final class VideoSpikeModel {
    let player = MDKPlayer()

    var urlText = "http://10.70.252.199:8765/hevc10.mkv"
    var headersText = "Referer: https://115.com/\nCookie: UID=spike; acw_tc=leech\nUser-Agent: Mozilla/5.0 115Browser/30.4.0"
    var isPlaying = false
    var positionMs: Int64 = 0
    var durationMs: Int64 = 0
    var bufferedMs: Int64 = 0
    var videoInfo: MDKPlayer.VideoInfo?
    var decoder = ""
    var log: [String] = []

    private let diagnostics = DiagnosticLog.shared
    private var accessedURL: URL?
    private var ticker: Task<Void, Never>?

    init() {
        // Same defaults fvp applies on iOS, so behaviour matches the Flutter build.
        player.setVideoDecoders(["VT", "FFmpeg", "dav1d"])
        player.setProperty("video.decoder", "shader_resource=0")
        player.setProperty("avformat.strict", "experimental")
        player.setProperty("avformat.safe", "0")
        player.setProperty("avio.reconnect", "1")
        player.setProperty("avio.reconnect_delay_max", "7")
        player.setProperty("avformat.extension_picky", "0")

        player.onStateChanged { state in
            DiagnosticLog.shared.write("video_player", "state", ["state": "\(state)"])
            Task { @MainActor in self.isPlaying = state == .playing }
        }
        player.onMediaStatus { status in
            DiagnosticLog.shared.write("video_player", "media_status", ["status": status.names])
            Task { @MainActor in self.append("status \(status.names)") }
        }
        player.onEvent { event in
            // Per-percent buffering progress; media_status already records
            // buffering start and end.
            guard event.category != "reader.buffering" else { return }
            DiagnosticLog.shared.write("video_player", "event", ["category": event.category, "detail": event.detail, "error": event.error])
            Task { @MainActor in
                if event.category == "decoder.video" { self.decoder = event.detail }
                self.append("event \(event.category) \(event.detail) \(event.error)")
            }
        }
        registerRemoteCommands()
    }

    func openRemote() async {
        let headers = headersText
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> (name: String, value: String)? in
                guard let colon = line.firstIndex(of: ":") else { return nil }
                return (
                    String(line[..<colon]).trimmingCharacters(in: .whitespaces),
                    String(line[colon...].dropFirst()).trimmingCharacters(in: .whitespaces)
                )
            }
        player.setHTTPHeaders(headers)
        await open(urlText)
    }

    func openLocal(_ url: URL) async {
        accessedURL?.stopAccessingSecurityScopedResource()
        _ = url.startAccessingSecurityScopedResource()
        accessedURL = url
        player.setHTTPHeaders([])
        await open(url.path)
    }

    private func open(_ media: String) async {
        decoder = ""
        videoInfo = nil
        durationMs = 0
        append("open \(media)")
        let started = Date()
        diagnostics.write("video_player", "open", ["media": media])
        let ok = await player.open(media)
        let elapsed = Int(Date().timeIntervalSince(started) * 1000)
        append("prepare \(ok ? "ok" : "failed") in \(elapsed)ms")
        diagnostics.write("video_player", "prepare", ["ok": ok, "elapsedMs": elapsed, "status": player.mediaStatus.names])
        guard ok else { return }
        durationMs = player.durationMs
        videoInfo = player.videoInfo
        if let info = videoInfo {
            diagnostics.write("video_player", "media_info", [
                "durationMs": durationMs, "codec": info.codec, "pixelFormat": info.pixelFormat,
                "width": info.width, "height": info.height, "frameRate": Double(info.frameRate),
            ])
        }
        player.state = .playing
        startTicker()
    }

    func togglePlay() {
        diagnostics.write("video_player", isPlaying ? "pause" : "play", ["positionMs": player.positionMs])
        player.state = isPlaying ? .paused : .playing
    }

    func seek(toMs position: Int64) {
        diagnostics.write("video_player", "seek", ["fromMs": player.positionMs, "toMs": position])
        player.seek(toMs: position)
        positionMs = position
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task {
            var tick = 0
            while !Task.isCancelled {
                positionMs = player.positionMs
                bufferedMs = player.bufferedMs
                updateNowPlaying()
                if isPlaying && tick % 10 == 0 {
                    diagnostics.write("video_player", "progress", ["positionMs": positionMs, "bufferedMs": bufferedMs])
                }
                tick += 1
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func append(_ line: String) {
        log.append("\(Date().formatted(date: .omitted, time: .standard)) \(line)")
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Tonari 视频验证",
            MPMediaItemPropertyPlaybackDuration: Double(durationMs) / 1000,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(positionMs) / 1000,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
    }

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in
            DiagnosticLog.shared.write("now_playing", "command", ["command": "play"])
            MainActor.assumeIsolated { self.player.state = .playing }
            return .success
        }
        center.pauseCommand.addTarget { _ in
            DiagnosticLog.shared.write("now_playing", "command", ["command": "pause"])
            MainActor.assumeIsolated { self.player.state = .paused }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { event in
            let position = (event as! MPChangePlaybackPositionCommandEvent).positionTime
            DiagnosticLog.shared.write("now_playing", "command", ["command": "seek", "positionS": position])
            MainActor.assumeIsolated { self.seek(toMs: Int64(position * 1000)) }
            return .success
        }
    }
}
