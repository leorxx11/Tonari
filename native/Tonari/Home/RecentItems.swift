import SwiftUI
import TonariCore

/// A play-history entry with the cover and target it opens.
nonisolated struct RecentItem: Identifiable, Sendable {
    let entry: PlayHistoryEntry
    let coverPath: String?
    /// Set when the entry is a work still in the library.
    let workId: String?
    /// 1-based position of the work's last track within its folder.
    let trackNumber: Int?

    var id: String { entry.id }

    static func fetch(limit: Int, _ db: Database) throws -> [RecentItem] {
        let entries = try CollectionQueries.recentlyPlayed(limit: limit, db)
        let works = try Work.filter(keys: entries.compactMap(\.workId)).filter(Column("is_removed") == false).fetchAll(db)
        let worksById = Dictionary(uniqueKeysWithValues: works.map { ($0.productId, $0) })
        let videos = try VideoItem.filter(keys: entries.map(\.id)).fetchAll(db)
        let coversById = Dictionary(uniqueKeysWithValues: videos.map { ($0.id, $0.coverPath) })
        return try entries.map { entry in
            if entry.kind == "work", let work = entry.workId.flatMap({ worksById[$0] }) {
                RecentItem(entry: entry, coverPath: work.mainImageLocalPath, workId: work.productId, trackNumber: try HomeQueries.trackNumber(of: work, db))
            } else {
                RecentItem(entry: entry, coverPath: coversById[entry.id] ?? nil, workId: nil, trackNumber: nil)
            }
        }
    }

    var caption: String {
        if let trackNumber { return "听到第 \(trackNumber) 首" }
        if let duration = entry.durationMs, duration > 0 {
            return "看到 \(min(100, entry.positionMs * 100 / duration))%"
        }
        return entry.playedAt.formatted(.relative(presentation: .named))
    }
}

struct RecentTile: View {
    let item: RecentItem
    var width: CGFloat = 150
    @Environment(PlaybackController.self) private var player
    @Environment(VideoController.self) private var video
    @Environment(AppModel.self) private var model

    var body: some View {
        let tile = VStack(alignment: .leading, spacing: 2) {
            LocalImage(path: item.coverPath)
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 8))
                .padding(.bottom, 4)
            Text(item.entry.title).font(.subheadline).lineLimit(1)
            Text(item.caption).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(width: width)
        .contentShape(.rect)
        if let workId = item.workId {
            NavigationLink(value: Route.work(workId)) { tile }.buttonStyle(.plain)
        } else if let playable = PlayableVideo(history: item.entry) {
            Button { model.playVideo(playable, with: video) } label: { tile }
                .buttonStyle(.plain)
        } else if let file = item.entry.remoteFile {
            Button {
                player.play(files: [file], at: 0, sourceName: item.entry.sourceName ?? P115Client.sourceName)
            } label: {
                tile
            }
            .buttonStyle(.plain)
        } else {
            tile
        }
    }
}
