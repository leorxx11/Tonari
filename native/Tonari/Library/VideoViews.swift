import SwiftUI
import TonariCore

/// Plain video list; the video library proper arrives with playback in N5.
struct VideoListView: View {
    @Environment(\.appDatabase) private var database
    @State private var videos: [VideoItem] = []

    var body: some View {
        List(videos) { video in
            VideoRow(video: video)
        }
        .listStyle(.plain)
        .overlay {
            if videos.isEmpty {
                ContentUnavailableView("视频库还是空的", systemImage: "film")
            }
        }
        .task {
            await database.observe({ try VideoItem.order(Column("added_at").desc).fetchAll($0) }) { videos = $0 }
        }
    }
}

struct VideoRow: View {
    let video: VideoItem

    var body: some View {
        HStack(spacing: 12) {
            LocalImage(path: video.coverPath)
                .frame(width: 96, height: 54)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                Text(video.displayTitle).font(.subheadline.weight(.medium)).lineLimit(2)
                Text(video.sourceName).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

extension VideoItem {
    var displayTitle: String { customTitle ?? fileName }
}
