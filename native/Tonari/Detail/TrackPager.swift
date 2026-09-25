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

    var body: some View {
        ColumnPager(count: tracks.count, focus: tracks.firstIndex { $0.id == focusId }, identity: tracks.map(\.id)) { index, last in
            row(index, last: last)
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
            .frame(height: PagerRow.height)
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

/// Rows in columns of four that page sideways, after Apple Music's top
/// songs: the next column peeks in, and the page opens at the column
/// holding `focus`.
struct ColumnPager<Row: View>: View {
    let count: Int
    let focus: Int?
    /// Refocuses when this changes, e.g. another folder's tracks.
    let identity: [String]
    @ViewBuilder let row: (_ index: Int, _ last: Bool) -> Row

    @State private var column: Int?

    private static var rows: Int { 4 }

    var body: some View {
        let columns = stride(from: 0, to: count, by: Self.rows).map { Array($0..<min($0 + Self.rows, count)) }
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(columns.indices, id: \.self) { index in
                    VStack(spacing: 0) {
                        ForEach(columns[index], id: \.self) { row($0, $0 == columns[index].last) }
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
        .frame(height: CGFloat(min(count, Self.rows)) * PagerRow.height)
        .onChange(of: identity, initial: true) {
            column = (focus ?? 0) / Self.rows
        }
    }
}

enum PagerRow {
    static let height: CGFloat = 52
}
