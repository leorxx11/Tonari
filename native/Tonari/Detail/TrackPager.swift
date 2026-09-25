import SwiftUI
import TonariCore

/// A folder's tracks in columns of four that page sideways, after Apple
/// Music's top songs: the next column peeks in, and the page opens at the
/// column holding `focusId`.
struct TrackPager: View {
    let tracks: [Track]
    let focusId: String?
    let subtitled: Set<String>
    let showsOriginal: Bool
    let play: (Int) -> Void
    let previewSubtitle: (Track) -> Void
    let reveal: (Track) -> Void

    @Environment(PlaybackController.self) private var player
    @State private var column: Int?

    private static let rows = 4
    private static let rowHeight: CGFloat = 52

    var body: some View {
        let columns = stride(from: 0, to: tracks.count, by: Self.rows).map { Array($0..<min($0 + Self.rows, tracks.count)) }
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(columns.indices, id: \.self) { index in
                    VStack(spacing: 0) {
                        ForEach(columns[index], id: \.self) { row($0, last: $0 == columns[index].last) }
                    }
                    .containerRelativeFrame(.horizontal) { width, _ in columns.count > 1 ? width * 0.88 : width }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $column, anchor: .leading)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .frame(height: CGFloat(min(tracks.count, Self.rows)) * Self.rowHeight)
        .onChange(of: tracks.map(\.id), initial: true) {
            column = (tracks.firstIndex { $0.id == focusId } ?? 0) / Self.rows
        }
    }

    private func row(_ index: Int, last: Bool) -> some View {
        let track = tracks[index]
        return Button { play(index) } label: {
            HStack(spacing: 12) {
                Group {
                    if player.currentTrack?.id == track.id {
                        Image(systemName: "waveform")
                            .foregroundStyle(.tint)
                            .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                    } else {
                        Text("\(index + 1)").foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.monospacedDigit())
                .frame(width: 24)
                Text(title(track)).lineLimit(1)
                if subtitled.contains(track.id) {
                    Image(systemName: "captions.bubble").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if track.durationMs > 0 {
                    Text(Formatting.trackTime(ms: track.durationMs))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: Self.rowHeight)
            .overlay(alignment: .bottom) {
                if !last { Divider().padding(.leading, 36) }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("从这首播放", systemImage: "play") { play(index) }
            if subtitled.contains(track.id) {
                Button("预览字幕", systemImage: "captions.bubble") { previewSubtitle(track) }
            }
            Button("在文件中显示", systemImage: "folder") { reveal(track) }
        }
    }

    private func title(_ track: Track) -> String {
        if !showsOriginal, let zh = track.titleZh, !zh.isEmpty { zh } else { track.title }
    }
}
