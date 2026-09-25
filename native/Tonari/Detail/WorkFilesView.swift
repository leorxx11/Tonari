import SwiftUI
import TonariCore

/// A work's files as folders, opening at the folder most likely to hold the
/// main audio. Tapping a track plays its folder from it.
struct WorkFilesView: View {
    let productId: String

    @Environment(\.appDatabase) private var database
    @Environment(PlaybackController.self) private var player
    @State private var tree: [WorkTreeNode] = []
    @State private var path: [String] = []
    @State private var loaded = false

    var body: some View {
        List {
            ForEach(currentLevel) { node in
                switch node {
                case .folder(let name, let children):
                    Button {
                        path.append(name)
                    } label: {
                        FileNodeRow(icon: "folder.fill", tint: .blue, title: name, detail: folderDetail(node, children: children))
                    }
                    .tint(.primary)
                case .track(let track):
                    Button {
                        play(track)
                    } label: {
                        FileNodeRow(
                            icon: player.currentTrack?.id == track.id ? "waveform" : "music.note", tint: .pink, title: track.titleZh ?? track.title,
                            detail: [Formatting.trackTime(ms: track.durationMs), Formatting.bytes(track.fileSizeBytes)].joined(separator: " · ")
                        )
                    }
                    .tint(.primary)
                case .file(let file):
                    let (icon, tint) = Self.icon(for: file.fileKind)
                    FileNodeRow(icon: icon, tint: tint, title: file.fileName, detail: Formatting.bytes(file.fileSizeBytes))
                }
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .top) { breadcrumbs }
        .navigationTitle("资源")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if loaded && tree.isEmpty {
                ContentUnavailableView("没有文件", systemImage: "folder")
            }
        }
        .task {
            await database.observe({ db in
                WorkTree.build(tracks: try WorkQueries.tracks(of: productId).fetchAll(db), files: try WorkQueries.files(of: productId).fetchAll(db))
            }) { nodes in
                if !loaded {
                    path = WorkTree.autoPath(nodes)
                    loaded = true
                }
                tree = nodes
            }
        }
    }

    private func play(_ track: Track) {
        let queue = try! PlaybackStore(database: database).queue(for: productId, folder: track.folderPath)
        player.play(queue, at: queue.tracks.firstIndex { $0.id == track.id }!)
        TrackFolderMemory.remember(track.folderPath, for: productId)
    }

    private var currentLevel: [WorkTreeNode] {
        path.reduce(tree) { level, name in
            level.first { $0.name == name && !$0.children.isEmpty }?.children ?? []
        }
    }

    private var breadcrumbs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button(productId) { path = [] }
                    .disabled(path.isEmpty)
                ForEach(Array(path.enumerated()), id: \.offset) { index, name in
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    Button(name) { path = Array(path.prefix(index + 1)) }
                        .disabled(index == path.count - 1)
                }
            }
            .font(.subheadline)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func folderDetail(_ node: WorkTreeNode, children: [WorkTreeNode]) -> String {
        var parts = ["\(children.count) 项"]
        if node.audioCount > 0 { parts.append("\(node.audioCount) 音频") }
        if node.totalDurationMs > 0 { parts.append(Formatting.trackTime(ms: node.totalDurationMs)) }
        return parts.joined(separator: " · ")
    }

    static func icon(for kind: String) -> (String, Color) {
        switch kind {
        case "image": ("photo", .green)
        case "subtitle": ("captions.bubble", .cyan)
        case "text": ("doc.text", .orange)
        case "video": ("film", .purple)
        default: ("doc", .gray)
        }
    }
}

private struct FileNodeRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).lineLimit(3)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
