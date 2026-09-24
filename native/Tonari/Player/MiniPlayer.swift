import SwiftUI
import TonariCore

/// Sits above the tab bar; when the tab bar minimizes on scroll it moves
/// inline beside it and drops to title plus play button.
struct MiniPlayer: View {
    @Environment(PlaybackController.self) private var player
    @Environment(AppModel.self) private var model
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: 10) {
            PlayerArtwork(path: player.work?.mainImageLocalPath, cornerRadius: 6)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(player.title).font(.subheadline.weight(.medium)).lineLimit(1)
                if placement != .inline {
                    Text(player.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            ProgressRingButton()
            if placement != .inline {
                Button("下一首", systemImage: "forward.fill", action: player.next)
                    .labelStyle(.iconOnly)
                    .font(.body)
                    .frame(width: 32, height: 36)
                    .disabled(!player.hasNext)
            }
        }
        .padding(.horizontal, 12)
        .contentShape(.rect)
        .onTapGesture { model.showingPlayer = true }
        .tint(.primary)
    }
}

struct PlayPauseButton: View {
    @Environment(PlaybackController.self) private var player

    var body: some View {
        if player.isLoading {
            ProgressView()
        } else {
            Button(player.isPlaying ? "暂停" : "播放", systemImage: player.isPlaying ? "pause.fill" : "play.fill", action: player.togglePlay)
                .labelStyle(.iconOnly)
                .contentTransition(.symbolEffect(.replace))
        }
    }
}

/// Play button ringed by the track's progress, as in Podcasts.
private struct ProgressRingButton: View {
    @Environment(PlaybackController.self) private var player

    var body: some View {
        let fraction = player.durationMs > 0 ? Double(player.positionMs) / Double(player.durationMs) : 0
        ZStack {
            Circle().stroke(.quaternary, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            PlayPauseButton().font(.footnote)
        }
        .frame(width: 32, height: 32)
    }
}

/// A work's cover, or a cloud glyph for files played from a browser.
struct PlayerArtwork: View {
    let path: String?
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let path {
                LocalImage(path: path)
            } else {
                ZStack {
                    Color(.secondarySystemBackground)
                    Image(systemName: "icloud").foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}
