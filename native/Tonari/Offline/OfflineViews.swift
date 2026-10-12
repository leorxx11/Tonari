import SwiftUI
import TonariCore

/// Apple Music's download ring: a track on the fill colour, progress in the tint.
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            Circle().stroke(Color(.tertiarySystemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.linear(duration: 0.2), value: progress)
    }
}

/// Under a kept work's play buttons: how far its download has got, with
/// pause and resume, then what it takes on the device once done.
struct OfflineStatusLine: View {
    let productId: String

    @Environment(OfflineDownloads.self) private var offline

    var body: some View {
        if let entry = offline.entry(productId) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: entry.status.isComplete ? "arrow.down.circle.fill" : "arrow.down.circle")
                    Text(entry.status.isComplete ? "已下载到本机 · \(Formatting.bytes(entry.status.totalBytes))" : offline.progressText(of: entry))
                        .monospacedDigit()
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if !entry.status.isComplete {
                        Button(offline.paused ? "继续" : "暂停") {
                            if offline.paused { offline.resume() } else { offline.pause() }
                        }
                        .foregroundStyle(.tint)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if !entry.status.isComplete {
                    ProgressView(value: offline.progress(of: entry))
                }
            }
        }
    }
}

extension Notices {
    /// Confirms a work was added to the queue, which doesn't move while paused.
    func downloadAdded(paused: Bool) {
        if paused { show("已加入下载，下载已暂停", .info) } else { show("已加入下载") }
    }
}

/// A track's mark in the track list: an arrow once downloaded, a ring while
/// it downloads, nothing otherwise.
struct TrackDownloadMark: View {
    let track: Track

    @Environment(OfflineDownloads.self) private var offline

    var body: some View {
        if let fraction = offline.fraction(of: track) {
            ProgressRing(progress: fraction, lineWidth: 2).frame(width: 13, height: 13)
        } else if OfflineFiles.shared.localURL(for: track) != nil, offline.entry(track.workId) != nil {
            Image(systemName: "arrow.down.circle").font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Shown on Home and the library while anything is left to download: the
/// overall ring, opening the downloads sheet.
struct DownloadsToolbarButton: View {
    @Environment(OfflineDownloads.self) private var offline
    @State private var showing = false

    var body: some View {
        if let progress = offline.overallProgress {
            Button { showing = true } label: {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 2.5).frame(width: 22, height: 22)
                    if offline.paused {
                        Image(systemName: "pause.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(.tint)
                    } else {
                        Image(systemName: "arrow.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.tint)
                    }
                }
            }
            .accessibilityLabel("下载")
            .sheet(isPresented: $showing) { DownloadsSheet() }
        }
    }
}

/// The works still downloading, each with its bar; pause or resume them all.
struct DownloadsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(OfflineDownloads.self) private var offline
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(offline.unfinished) { entry in
                Button {
                    dismiss()
                    model.openWork(entry.id)
                } label: {
                    OfflineWorkRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .overlay {
                if offline.unfinished.isEmpty {
                    ContentUnavailableView("全部下载完成", systemImage: "checkmark.circle")
                }
            }
            .navigationTitle("下载")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !offline.unfinished.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(offline.paused ? "全部继续" : "全部暂停") {
                            if offline.paused { offline.resume() } else { offline.pause() }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 资料库 → 已下载: every kept work, swipe to delete.
struct OfflineDownloadsView: View {
    @Environment(AppModel.self) private var model
    @Environment(OfflineDownloads.self) private var offline

    var body: some View {
        List {
            ForEach(offline.entries) { entry in
                Button { model.push(.work(entry.id)) } label: {
                    OfflineWorkRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets { offline.drop(offline.entries[index].id) }
            }
        }
        .overlay {
            if offline.entries.isEmpty {
                ContentUnavailableView("没有下载", systemImage: "arrow.down.circle", description: Text("在 115 作品页的 ⋯ 里选「下载到本机」"))
            }
        }
        .navigationTitle("已下载")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !offline.unfinished.isEmpty {
                Button(offline.paused ? "全部继续" : "全部暂停") {
                    if offline.paused { offline.resume() } else { offline.pause() }
                }
            }
        }
    }
}

private struct OfflineWorkRow: View {
    let entry: OfflineQueries.Entry

    @Environment(OfflineDownloads.self) private var offline

    var body: some View {
        HStack(spacing: 12) {
            LocalImage(path: entry.work.mainImageLocalPath)
                .frame(width: 64, height: 48)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.work.displayTitle).lineLimit(1)
                Text(detail)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if !entry.status.isComplete {
                    ProgressView(value: offline.progress(of: entry))
                }
            }
        }
        .contentShape(.rect)
    }

    private var detail: String {
        let status = entry.status
        return status.isComplete ? "\(status.total) 首 · \(Formatting.bytes(status.totalBytes))" : offline.progressText(of: entry)
    }
}
