import SwiftUI
import TonariCore

/// Everything played, newest first, split into audio (works and files) and
/// video. Works open their page; 115 audio files play again in place.
struct PlayHistoryView: View {
    enum Kind: String, CaseIterable {
        case audio = "音频"
        case video = "视频"

        func contains(_ entry: PlayHistoryEntry) -> Bool {
            self == .video ? entry.kind == "video" : entry.kind != "video"
        }
    }

    @Environment(\.appDatabase) private var database
    @State private var kind = Kind.audio
    @State private var items: [RecentItem] = []
    @State private var loaded = false
    @State private var confirmingClear = false

    var body: some View {
        let shown = items.filter { kind.contains($0.entry) }
        List {
            ForEach(shown) { item in
                HistoryRow(item: item)
                    .swipeActions {
                        Button("删除", systemImage: "trash", role: .destructive) {
                            try! PlaybackStore(database: database).removeHistory(item.id)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .overlay {
            if loaded && shown.isEmpty {
                ContentUnavailableView("还没有\(kind.rawValue)播放记录", systemImage: "clock.arrow.circlepath")
            }
        }
        .navigationTitle("播放历史")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            Picker("类型", selection: $kind) {
                ForEach(Kind.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: Route.listenStats) {
                    Label("收听统计", systemImage: "chart.bar.xaxis")
                }
                Button("清空历史", systemImage: "trash") { confirmingClear = true }
                    .disabled(items.isEmpty)
            }
        }
        .alert("清空播放历史", isPresented: $confirmingClear) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { try! PlaybackStore(database: database).clearHistory() }
        } message: {
            Text("删除所有历史记录？此操作不可撤销。收听统计不受影响。")
        }
        .task {
            await database.observe({ db in try RecentItem.fetch(limit: PlaybackStore.maxHistoryEntries, db) }) {
                items = $0
                loaded = true
            }
        }
    }
}

private struct HistoryRow: View {
    let item: RecentItem

    @Environment(PlaybackController.self) private var player
    @Environment(VideoController.self) private var video
    @Environment(AppModel.self) private var model

    var body: some View {
        if let workId = item.workId {
            NavigationLink(value: Route.work(workId)) { content }
        } else if let file = item.entry.remoteFile {
            Button {
                let sourceName = item.entry.sourceName ?? P115Client.sourceName
                if file.kind == .video {
                    model.playVideo(file, sourceName: sourceName, with: video)
                } else {
                    player.play(files: [file], at: 0, sourceName: sourceName)
                }
            } label: {
                content
            }
            .tint(.primary)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 12) {
            Group {
                if item.coverPath != nil {
                    LocalImage(path: item.coverPath)
                } else {
                    ZStack {
                        Color(.secondarySystemBackground)
                        Image(systemName: symbol).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 52, height: item.entry.kind == "video" ? 30 : 52)
            .frame(height: 52)
            .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.entry.title).font(.subheadline).lineLimit(2)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var symbol: String {
        switch item.entry.kind {
        case "work": "music.note.list"
        case "video": "film"
        default: "music.note"
        }
    }

    private var detail: String {
        let entry = item.entry
        var parts = [entry.kind == "work" ? "作品" : entry.kind == "video" ? "视频" : "音频"]
        if entry.kind == "work" && item.workId == nil { parts.append("已不在媒体库") }
        if let source = entry.sourceName, !source.isEmpty { parts.append(source) }
        parts.append(entry.playedAt.formatted(.relative(presentation: .named)))
        if entry.kind == "video", let duration = entry.durationMs, duration > 0, entry.positionMs > 0 {
            parts.append("看到 \(min(100, entry.positionMs * 100 / duration))%")
        }
        return parts.joined(separator: " · ")
    }
}
