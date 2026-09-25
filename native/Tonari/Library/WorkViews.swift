import SwiftUI
import TonariCore

/// DLsite cover at its 4:3 ratio, with a small cloud for 115 works and a
/// heart for favorites in the corner.
struct WorkCover: View {
    let work: Work
    let isRemote: Bool
    var cornerRadius: CGFloat = 8

    var body: some View {
        LocalImage(path: work.mainImageLocalPath)
            .aspectRatio(4 / 3, contentMode: .fit)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(alignment: .bottomTrailing) {
                if isRemote || work.isFavorite {
                    HStack(spacing: 4) {
                        if isRemote { Image(systemName: "icloud.fill") }
                        if work.isFavorite { Image(systemName: "heart.fill") }
                    }
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: .capsule)
                    .padding(6)
                }
            }
    }
}

extension Work {
    /// Up to two voice actors, the circle when none are known.
    var castLine: String? {
        guard !voiceActors.isEmpty else { return circleName }
        let names = voiceActors.prefix(2).joined(separator: "、")
        return voiceActors.count > 2 ? names + " 等" : names
    }

    /// Voice actors · circle, then any extras, skipping what's unknown.
    func creditLine(_ extras: String?...) -> String {
        ([voiceActors.isEmpty ? nil : voiceActors.joined(separator: "、"), circleName] + extras)
            .compactMap(\.self).joined(separator: " · ")
    }
}

struct RatingStars: View {
    let rating: Double
    var size: CGFloat = 11

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { i in
                let value = Double(i)
                Image(systemName: rating >= value ? "star.fill" : rating >= value - 0.5 ? "star.leadinghalf.filled" : "star")
            }
        }
        .font(.system(size: size))
        .foregroundStyle(.orange)
    }
}

struct WorkGridCell: View {
    let work: Work
    let isRemote: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            WorkCover(work: work, isRemote: isRemote)
                .padding(.bottom, 4)
            Text(work.displayTitle)
                .font(.subheadline)
                .lineLimit(1)
            Text(work.castLine ?? " ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(.rect)
    }
}

struct WorkListRow: View {
    let work: Work
    let isRemote: Bool
    let trackCount: Int

    var body: some View {
        HStack(spacing: 12) {
            LocalImage(path: work.mainImageLocalPath)
                .frame(width: 64, height: 48)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(work.displayTitle).lineLimit(1)
                Text(work.creditLine())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                if work.isFavorite { Image(systemName: "heart.fill").foregroundStyle(.pink) }
                if isRemote { Image(systemName: "icloud").foregroundStyle(.secondary) }
            }
            .font(.caption)
            Text("\(trackCount) 首")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// One work to a row with the cover at full width; replaces the old card.
struct WorkCoverCell: View {
    let work: Work
    let isRemote: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            WorkCover(work: work, isRemote: isRemote, cornerRadius: 12)
                .padding(.bottom, 6)
            Text(work.displayTitle)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(work.creditLine(work.releaseDate.map(Formatting.date)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(.rect)
    }
}

extension View {
    /// Long-press preview and menu shared by every place a work is listed.
    /// Without a track count the play action is left out.
    func workContextMenu(_ work: Work, trackCount: Int?, removeFromCollection: (() -> Void)? = nil) -> some View {
        modifier(WorkContextMenu(work: work, trackCount: trackCount, removeFromCollection: removeFromCollection))
    }
}

private struct WorkContextMenu: ViewModifier {
    let work: Work
    let trackCount: Int?
    let removeFromCollection: (() -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(PlaybackController.self) private var player
    @Environment(\.appDatabase) private var database

    func body(content: Content) -> some View {
        content.contextMenu {
            if let trackCount, trackCount > 0 {
                Button("播放", systemImage: "play.fill", action: play)
            }
            Button(work.isFavorite ? "取消收藏" : "添加收藏", systemImage: work.isFavorite ? "heart.slash" : "heart") {
                try! database.setFavorite(work.productId, !work.isFavorite)
            }
            Button("加入分组…", systemImage: "folder.badge.plus") {
                model.collectionPickerWork = work
            }
            Button("重新扫描", systemImage: "arrow.clockwise", action: rescan)
                .disabled(model.tasks.isBusy)
            if let removeFromCollection {
                Button("移出分组", systemImage: "folder.badge.minus", role: .destructive, action: removeFromCollection)
            } else {
                Button("移除作品", systemImage: "trash", role: .destructive) { model.removingWork = work }
            }
        } preview: {
            VStack(alignment: .leading, spacing: 4) {
                WorkCover(work: work, isRemote: false, cornerRadius: 0)
                Group {
                    Text(work.displayTitle).font(.headline).lineLimit(2)
                    Text(work.creditLine()).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 12)
            .frame(width: 320)
        }
    }

    private func play() {
        player.playWork(work.productId, database: database)
    }

    private func rescan() {
        Task {
            await model.tasks.run("重新扫描作品", detail: work.productId) {
                let summary = try await model.reimport(work, database: database)
                return "作品已重新扫描：\(summary.tracksTotal) 个音轨"
            }
        }
    }
}
