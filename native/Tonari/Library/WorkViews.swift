import SwiftUI
import TonariCore

/// DLsite cover (4:3) with the RJ number, release date, cloud badge and a
/// favorite toggle laid over its corners.
struct WorkCover: View {
    let work: Work
    let isRemote: Bool
    var compact = false

    @Environment(\.appDatabase) private var database

    var body: some View {
        LocalImage(path: work.mainImageLocalPath)
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                Pill(text: work.productId).padding(6)
            }
            .overlay(alignment: .bottomTrailing) {
                if let date = work.releaseDate, !compact {
                    Pill(text: Formatting.date(date)).padding(6)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if isRemote {
                    Image(systemName: "icloud.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.55), in: .circle)
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    try! database.setFavorite(work.productId, !work.isFavorite)
                } label: {
                    Image(systemName: work.isFavorite ? "heart.fill" : "heart")
                        .font(.footnote.bold())
                        .foregroundStyle(work.isFavorite ? .pink : .white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.4), in: .circle)
                }
                .buttonStyle(.plain)
                .padding(4)
                .accessibilityLabel(work.isFavorite ? "取消收藏" : "添加收藏")
            }
    }
}

struct Pill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.monospacedDigit().weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.55), in: .capsule)
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

/// Rating · review count · total length, whichever are known.
struct WorkMetaLine: View {
    let work: Work
    let durationMs: Int?

    var body: some View {
        HStack(spacing: 6) {
            if let rating = work.rating, rating > 0 {
                RatingStars(rating: rating)
                Text(rating.formatted(.number.precision(.fractionLength(0...1))))
                    .foregroundStyle(.orange)
                if let count = work.ratingCount {
                    Text("(\(count))").foregroundStyle(.secondary)
                }
            }
            if let durationMs, durationMs > 0 {
                Label(Formatting.hours(ms: durationMs), systemImage: "clock")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }
}

/// Tappable CV (green), series (orange) and tag (gray) capsules; tapping one
/// filters the library by it.
struct WorkChipsView: View {
    let work: Work
    var includeGenres = true
    var limit: Int?

    @Environment(AppModel.self) private var model

    var body: some View {
        let chips = allChips
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Array(chips.prefix(limit ?? chips.count)), id: \.self) { chip in
                Button(chip.value) { model.showInLibrary(chip) }
                    .buttonStyle(ChipButtonStyle(kind: chip.kind))
            }
        }
    }

    private var allChips: [WorkChip] {
        var chips = work.voiceActors.map { WorkChip(.voiceActor, $0) }
        if let series = work.seriesName, !series.isEmpty { chips.append(WorkChip(.series, series)) }
        if includeGenres { chips += work.genreNames.map { WorkChip(.genre, $0) } }
        return chips
    }
}

struct ChipButtonStyle: ButtonStyle {
    let kind: WorkChip.Kind

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        let (background, foreground): (Color, Color) = switch kind {
        case .voiceActor: (.teal, .white)
        case .series: (.orange, .white)
        case .genre, .circle: (Color(.systemGray5), .primary)
        }
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(background.opacity(configuration.isPressed ? 0.7 : 1), in: .capsule)
    }
}

struct WorkCard: View {
    let work: Work
    let isRemote: Bool
    let durationMs: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WorkCover(work: work, isRemote: isRemote)
            VStack(alignment: .leading, spacing: 8) {
                Text(work.displayTitle)
                    .font(.headline)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                if let circle = work.circleName {
                    Text(circle).font(.subheadline).foregroundStyle(.tint)
                }
                WorkMetaLine(work: work, durationMs: durationMs)
                if work.currentPrice != nil || work.dlCount != nil {
                    HStack(spacing: 12) {
                        if let price = work.currentPrice ?? work.officialPrice {
                            Text("\(price) JPY").foregroundStyle(.red).fontWeight(.semibold)
                        }
                        if let sales = work.dlCount {
                            Text("销量 \(Formatting.count(sales))").foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
                WorkChipsView(work: work, limit: 12)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

struct WorkGridCell: View {
    let work: Work
    let isRemote: Bool
    let durationMs: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WorkCover(work: work, isRemote: isRemote, compact: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(work.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text(work.circleName ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                WorkMetaLine(work: work, durationMs: durationMs)
            }
            .padding(8)
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
        .clipShape(.rect(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
    }
}

struct WorkRow: View {
    let work: Work
    let durationMs: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LocalImage(path: work.mainImageLocalPath)
                .frame(width: 88, height: 66)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 3) {
                Text(work.displayTitle).font(.subheadline.weight(.medium)).lineLimit(2)
                Text([work.productId, work.circleName].compactMap(\.self).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !work.voiceActors.isEmpty {
                    Text(work.voiceActors.joined(separator: "、"))
                        .font(.caption)
                        .foregroundStyle(.teal)
                        .lineLimit(1)
                }
                WorkMetaLine(work: work, durationMs: durationMs)
            }
        }
        .padding(.vertical, 2)
    }
}

extension View {
    /// Long-press menu shared by every place a work is listed.
    func workContextMenu(_ work: Work, removeFromCollection: (() -> Void)? = nil) -> some View {
        modifier(WorkContextMenu(work: work, removeFromCollection: removeFromCollection))
    }
}

private struct WorkContextMenu: ViewModifier {
    let work: Work
    let removeFromCollection: (() -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database

    func body(content: Content) -> some View {
        content.contextMenu {
            Button(work.isFavorite ? "取消收藏" : "添加收藏", systemImage: work.isFavorite ? "heart.slash" : "heart") {
                try! database.setFavorite(work.productId, !work.isFavorite)
            }
            Button("加入分组…", systemImage: "folder.badge.plus") {
                model.collectionPickerWork = work
            }
            if let removeFromCollection {
                Button("移出分组", systemImage: "folder.badge.minus", role: .destructive, action: removeFromCollection)
            } else {
                Button("移除作品", systemImage: "trash", role: .destructive) { model.removingWork = work }
            }
        }
    }
}
