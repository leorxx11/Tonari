import SwiftUI
import TonariCore

/// Sits above the tab bar; when the tab bar minimizes on scroll it moves
/// inline beside it and drops to a single line plus the play button. The
/// second line follows the subtitle, standing in for a floating caption.
/// Swipe sideways to change track; long-press for the player's options.
struct MiniPlayer: View {
    @Environment(NowPlaying.self) private var nowPlaying

    var body: some View {
        switch nowPlaying.front {
        case .audio: AudioMiniPlayer()
        case .video: VideoMiniPlayer()
        }
    }
}

private struct AudioMiniPlayer: View {
    @Environment(PlaybackController.self) private var player
    @Environment(AppModel.self) private var model
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @State private var showingSleep = false
    @State private var dragX: CGFloat = 0

    var body: some View {
        let line = player.currentLine
        HStack(spacing: 0) {
            PlayerArtwork(path: player.work?.mainImageLocalPath, cornerRadius: 6)
                .frame(width: 34, height: 34)
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    labels(title: player.title, detail: line ?? player.subtitle, inline: line)
                        .offset(x: dragX)
                    // The neighbouring track slides in from the side being revealed.
                    if dragX < 0, player.hasNext {
                        labels(title: player.title(at: player.index + 1), detail: player.subtitle, inline: nil)
                            .offset(x: dragX + width)
                    } else if dragX > 0, player.hasPrevious {
                        labels(title: player.title(at: player.index - 1), detail: player.subtitle, inline: nil)
                            .offset(x: dragX - width)
                    }
                }
                .frame(width: width, height: proxy.size.height, alignment: .leading)
                .gesture(swipe(width: width))
            }
            .frame(height: 36)
            // As in Apple Music, text slides right up to the cover and the
            // buttons and fades out there; the fade covers only the inset,
            // so text at rest stays fully opaque.
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: Self.inset)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: Self.inset)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: line)
            if player.sleep.isActive {
                Image(systemName: "moon.fill").font(.caption).foregroundStyle(.secondary).padding(.trailing, 6)
            }
            PlayPauseButton()
                .font(.body)
                .frame(width: 32, height: 36)
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
        .contextMenu { menu } preview: {
            MiniPlayerPreview(title: player.title, detail: player.subtitle) {
                PlayerArtwork(path: player.work?.mainImageLocalPath, cornerRadius: 8).frame(width: 56, height: 56)
            }
        }
        .tint(.primary)
        .sheet(isPresented: $showingSleep) { SleepTimerSheet() }
    }

    private static let inset: CGFloat = 10

    /// Inline, a single line: the subtitle when there is one, else the title.
    @ViewBuilder private func labels(title: String, detail: String, inline: String?) -> some View {
        Group {
            if placement == .inline {
                Text(inline ?? title).font(.subheadline.weight(.medium)).lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        .contentTransition(.opacity)
                }
            }
        }
        .padding(.horizontal, Self.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Follows the finger; past a third of the width the neighbour slides
    /// the rest of the way in and becomes the current track.
    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let dx = value.translation.width
                // Resist where there is no track to reveal.
                dragX = (dx < 0 && !player.hasNext) || (dx > 0 && !player.hasPrevious) ? dx * 0.2 : dx
            }
            .onEnded { value in
                let dx = value.translation.width
                let forward = dx < 0 && player.hasNext
                let backward = dx > 0 && player.hasPrevious
                guard abs(dx) > width / 3, forward || backward else {
                    withAnimation(.spring(duration: 0.3)) { dragX = 0 }
                    return
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    dragX = forward ? -width : width
                } completion: {
                    if forward { player.next() } else { player.previous() }
                    dragX = 0
                }
            }
    }

    @ViewBuilder private var menu: some View {
        Button(player.sleep.isActive ? "睡眠定时 · \(player.sleep.statusText ?? "")" : "睡眠定时", systemImage: "moon.zzz") {
            showingSleep = true
        }
        Picker(selection: Binding(get: { player.rate }, set: { player.setRate($0) })) {
            ForEach(PlayerView.rates, id: \.self) { Text("\($0.formatted())x") }
        } label: {
            Label("播放速度 · \(player.rate.formatted())x", systemImage: "gauge.with.dots.needle.67percent")
        }
        .pickerStyle(.menu)
        if player.currentSubtitle != nil, SubtitlePiP.isSupported {
            if player.pip.isActive {
                Button("关闭画中画字幕", systemImage: "pip.exit") { player.pip.stop() }
            } else {
                Button("画中画字幕", systemImage: "pip.enter") { player.startSubtitlePiP() }
            }
        }
        if let work = player.work {
            Button("查看作品", systemImage: "info.circle") { model.openWork(work.productId) }
        }
    }
}

/// The video in front: a 16:9 frame, title and play; long-press to set
/// the sleep timer or speed, or to end the video.
private struct VideoMiniPlayer: View {
    @Environment(VideoController.self) private var video
    @Environment(NowPlaying.self) private var nowPlaying
    @Environment(AppModel.self) private var model
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @State private var showingSleep = false

    var body: some View {
        HStack(spacing: 10) {
            VideoThumbnail(coverPath: video.libraryItem?.coverPath, cornerRadius: 5)
                .frame(width: 48)
            VStack(alignment: .leading, spacing: 1) {
                Text(video.title).font(.subheadline.weight(.medium)).lineLimit(1)
                if placement != .inline {
                    Text(video.sourceName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if video.isLoading {
                ProgressView().frame(width: 32, height: 36)
            } else {
                Button(video.isPlaying ? "暂停" : "播放", systemImage: video.isPlaying ? "pause.fill" : "play.fill", action: video.togglePlay)
                    .labelStyle(.iconOnly)
                    .contentTransition(.symbolEffect(.replace))
                    .font(.body)
                    .frame(width: 32, height: 36)
            }
        }
        .padding(.horizontal, 12)
        .contentShape(.rect)
        .onTapGesture { model.showingVideo = true }
        .contextMenu {
            Button("睡眠定时", systemImage: "moon.zzz") { showingSleep = true }
            Picker(selection: Binding(get: { video.rate }, set: { video.setRate($0) })) {
                ForEach(PlayerView.rates, id: \.self) { Text("\($0.formatted())x") }
            } label: {
                Label("播放速度 · \(video.rate.formatted())x", systemImage: "gauge.with.dots.needle.67percent")
            }
            .pickerStyle(.menu)
            Button("结束播放", systemImage: "xmark", role: .destructive) { nowPlaying.closeVideo() }
        } preview: {
            MiniPlayerPreview(title: video.title, detail: video.sourceName) {
                VideoThumbnail(coverPath: video.libraryItem?.coverPath)
                    .frame(width: 80)
            }
        }
        .tint(.primary)
        .sheet(isPresented: $showingSleep) { SleepTimerSheet() }
    }
}

private struct MiniPlayerPreview<Artwork: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let artwork: Artwork

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).lineLimit(2)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 56)
        .padding(12)
        .frame(width: 320)
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
