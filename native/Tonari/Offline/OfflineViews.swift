import SwiftUI
import TonariCore

/// Under a kept work's play button: how far its download has got.
struct OfflineStatusLine: View {
    let productId: String

    @Environment(OfflineDownloads.self) private var offline

    var body: some View {
        let _ = offline.revision
        if let status = offline.status(of: productId) {
            HStack(spacing: 6) {
                Image(systemName: status.isComplete ? "arrow.down.circle.fill" : "arrow.down.circle")
                Text(text(status)).monospacedDigit()
                Spacer(minLength: 0)
                if offline.paused && !status.isComplete {
                    Button("继续") { offline.resume() }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func text(_ status: OfflineQueries.Status) -> String {
        if status.isComplete {
            return "已下载到本机 · \(Formatting.bytes(OfflineFiles.shared.bytes(of: productId)))"
        }
        if offline.current?.workId == productId {
            return "正在下载 \(status.downloaded + 1)/\(status.total) · \(Int(offline.progress * 100))%"
        }
        return "\(offline.paused ? "下载已暂停" : "等待下载") · \(status.downloaded)/\(status.total)"
    }
}

/// Settings → 存储空间 → 离线下载: every kept work, swipe to delete.
struct OfflineDownloadsView: View {
    @Environment(AppModel.self) private var model
    @Environment(OfflineDownloads.self) private var offline
    @Environment(\.appDatabase) private var database

    var body: some View {
        let _ = offline.revision
        let entries = try! database.reader.read { try OfflineQueries.entries($0, files: .shared) }
        List {
            ForEach(entries) { entry in
                Button { model.push(.work(entry.id)) } label: {
                    HStack(spacing: 12) {
                        LocalImage(path: entry.work.mainImageLocalPath)
                            .frame(width: 64, height: 48)
                            .clipShape(.rect(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.work.displayTitle).lineLimit(1)
                            Text(detail(entry))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets { offline.drop(entries[index].id) }
            }
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("没有离线下载", systemImage: "arrow.down.circle", description: Text("在 115 作品页的 ⋯ 里选「下载到本机」"))
            }
        }
        .navigationTitle("离线下载")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ entry: OfflineQueries.Entry) -> String {
        let size = Formatting.bytes(OfflineFiles.shared.bytes(of: entry.id))
        if entry.status.isComplete { return "\(entry.status.total) 首 · \(size)" }
        let state = offline.current?.workId == entry.id ? "正在下载" : offline.paused ? "已暂停" : "等待下载"
        return "\(state) \(entry.status.downloaded)/\(entry.status.total) · \(size)"
    }
}
