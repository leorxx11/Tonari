import SwiftUI
import TonariCore

struct LibraryView: View {
    enum Kind: String, CaseIterable {
        case audio = "音声"
        case video = "视频"
    }

    @State private var kind = Kind.audio

    var body: some View {
        NavigationStack {
            Group {
                switch kind {
                case .audio: WorkListView()
                case .video: VideoListView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("媒体库", selection: $kind) {
                        ForEach(Kind.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Plain list to check restored data; the real library UI lands in N2.
private struct WorkListView: View {
    @Environment(\.appDatabase) private var database
    @State private var works: [Work] = []
    @State private var error: Error?

    var body: some View {
        List(works) { work in
            HStack(alignment: .top, spacing: 12) {
                LocalImage(path: work.mainImageLocalPath, size: CGSize(width: 64, height: 48))
                VStack(alignment: .leading, spacing: 2) {
                    Text(work.title).font(.subheadline).lineLimit(2)
                    Text([work.productId, work.circleName].compactMap(\.self).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !work.voiceActors.isEmpty {
                        Text(work.voiceActors.joined(separator: "、"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if let error {
                ContentUnavailableView("读取失败", systemImage: "exclamationmark.triangle", description: Text(String(describing: error)))
            } else if works.isEmpty {
                ContentUnavailableView("媒体库还是空的", systemImage: "music.note", description: Text("可在设置里从备份恢复"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !works.isEmpty {
                Text("\(works.count) 部作品").font(.caption).foregroundStyle(.secondary).padding(4)
            }
        }
        .task {
            let observation = ValueObservation.tracking { db in
                try Work
                    .filter(Column("is_removed") == false)
                    .order(Column("local_imported_at").desc)
                    .fetchAll(db)
            }
            do {
                for try await works in observation.values(in: database.reader) {
                    self.works = works
                }
            } catch {
                self.error = error
            }
        }
    }
}

private struct VideoListView: View {
    @Environment(\.appDatabase) private var database
    @State private var videos: [VideoItem] = []
    @State private var error: Error?

    var body: some View {
        List(videos) { video in
            HStack(spacing: 12) {
                LocalImage(path: video.coverPath, size: CGSize(width: 80, height: 45))
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.customTitle ?? video.fileName).font(.subheadline).lineLimit(2)
                    Text(video.sourceName).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if let error {
                ContentUnavailableView("读取失败", systemImage: "exclamationmark.triangle", description: Text(String(describing: error)))
            } else if videos.isEmpty {
                ContentUnavailableView("视频库还是空的", systemImage: "film")
            }
        }
        .task {
            let observation = ValueObservation.tracking { db in
                try VideoItem.order(Column("added_at").desc).fetchAll(db)
            }
            do {
                for try await videos in observation.values(in: database.reader) {
                    self.videos = videos
                }
            } catch {
                self.error = error
            }
        }
    }
}
