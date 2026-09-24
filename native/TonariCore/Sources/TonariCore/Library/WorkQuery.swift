import Foundation
import GRDB

public enum WorkSortField: String, CaseIterable, Sendable {
    case releaseDate, sales, rating, addedAt, lastPlayed, productId

    public var label: String {
        switch self {
        case .releaseDate: "发售日期"
        case .sales: "销量"
        case .rating: "评分"
        case .addedAt: "收录时间"
        case .lastPlayed: "最近播放"
        case .productId: "RJ 编号"
        }
    }

    /// Direction a field starts in when picked: newest / highest first.
    public var defaultDescending: Bool { self != .productId }

    var column: Column {
        switch self {
        case .releaseDate: Column("release_date")
        case .sales: Column("dl_count")
        case .rating: Column("rating")
        case .addedAt: Column("local_imported_at")
        case .lastPlayed: Column("last_played_at")
        case .productId: Column("product_id")
        }
    }
}

/// Persisted as `field:desc` / `field:asc` under `library.sort.works`, the
/// same format the Flutter build used.
public struct WorkSort: Equatable, Sendable {
    public static let preferenceKey = "library.sort.works"

    public var field: WorkSortField
    public var descending: Bool

    public init(field: WorkSortField, descending: Bool) {
        self.field = field
        self.descending = descending
    }

    public init(preference: String?) {
        let parts = (preference ?? "").split(separator: ":")
        guard let raw = parts.first, let field = WorkSortField(rawValue: String(raw)) else {
            self.init(field: .releaseDate, descending: true)
            return
        }
        self.init(field: field, descending: parts.last == "desc")
    }

    public var preference: String { "\(field.rawValue):\(descending ? "desc" : "asc")" }

    /// Picking the current field flips its direction; another field starts in
    /// its natural direction.
    public func selecting(_ field: WorkSortField) -> WorkSort {
        field == self.field
            ? WorkSort(field: field, descending: !descending)
            : WorkSort(field: field, descending: field.defaultDescending)
    }
}

public enum SourceFilter: String, CaseIterable, Sendable {
    case all, local, remote

    public var label: String {
        switch self {
        case .all: "全部"
        case .local: "本地"
        case .remote: "远程"
        }
    }
}

public struct WorkChip: Hashable, Sendable {
    public enum Kind: Sendable {
        case genre, voiceActor, series, circle
    }

    public var kind: Kind
    public var value: String

    public init(_ kind: Kind, _ value: String) {
        self.kind = kind
        self.value = value
    }

    public var label: String {
        switch kind {
        case .genre: "#\(value)"
        case .voiceActor: "CV：\(value)"
        case .series: "系列：\(value)"
        case .circle: "社团：\(value)"
        }
    }

    public func matches(_ work: Work) -> Bool {
        switch kind {
        case .genre: work.genreNames.contains(value)
        case .voiceActor: work.voiceActors.contains(value)
        case .series: work.seriesName == value
        case .circle: work.circleName == value
        }
    }
}

/// In-memory part of the library filter. Matching runs in Swift rather than
/// SQL LIKE so list columns match on their values, not their JSON encoding.
public struct WorkFilter: Equatable, Sendable {
    public var searchText = ""
    public var source = SourceFilter.all
    public var chips: [WorkChip] = []

    public init() {}

    public var isEmpty: Bool { searchText.trimmingCharacters(in: .whitespaces).isEmpty && chips.isEmpty }

    public mutating func add(_ chip: WorkChip) {
        if !chips.contains(chip) { chips.append(chip) }
    }

    /// `#tag` searches tag names only; anything else searches every field a
    /// work is remembered by.
    public func matches(_ work: Work) -> Bool {
        guard chips.allSatisfy({ $0.matches(work) }) else { return false }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if query.hasPrefix("#") {
            let tag = query.dropFirst().trimmingCharacters(in: .whitespaces)
            return tag.isEmpty || work.genreNames.contains { $0.lowercased().contains(tag) }
        }
        return query.isEmpty || work.matchesText(query)
    }
}

extension Work {
    public var genreNames: [String] { genresJson.map(\.name) }

    public var displayTitle: String {
        if let titleZh, !titleZh.isEmpty { titleZh } else { title }
    }

    func matchesText(_ query: String) -> Bool {
        let fields: [String?] = [
            productId, originalProductId, title, titleRomaji, titleZh, translatedTitle,
            circleName, seriesName, notes,
        ]
        let lists = [voiceActors, illustrators, scenarioWriters, musicians, userTags, genreNames]
        return fields.contains { $0?.lowercased().contains(query) == true }
            || lists.contains { $0.contains { $0.lowercased().contains(query) } }
    }
}

public enum WorkQueries {
    /// Visible (non-removed) works from the chosen sources in the chosen
    /// order. Missing sort values sink to the bottom in both directions; the
    /// RJ number breaks ties.
    public static func library(sort: WorkSort, source: SourceFilter) -> QueryInterfaceRequest<Work> {
        var request = Work.filter(Column("is_removed") == false)
        let remoteIds = ImportedFolder.filter(Column("type") != "local").select(Column("id"))
        let folder = Column("imported_folder_id")
        switch source {
        case .all: break
        case .remote: request = request.filter(remoteIds.contains(folder))
        case .local: request = request.filter(folder == nil || !remoteIds.contains(folder))
        }
        let key = sort.field.column
        // SQLite sorts NULL lowest, so DESC already puts it last.
        return request.order(sort.descending ? key.desc : key.ascNullsLast, Column("product_id"))
    }

    public static func remoteFolderIds(_ db: Database) throws -> Set<String> {
        try Set(String.fetchAll(db, ImportedFolder.filter(Column("type") != "local").select(Column("id"))))
    }

    /// Total audio length per work.
    public static func durations(_ db: Database) throws -> [String: Int] {
        let rows = try Row.fetchAll(db, sql: "SELECT work_id, SUM(duration_ms) AS total FROM tracks GROUP BY work_id")
        return Dictionary(uniqueKeysWithValues: rows.map { ($0["work_id"], $0["total"] ?? 0) })
    }

    /// Picks from the whole audio library, ignoring the library's filters.
    public static func random(_ db: Database) throws -> Work? {
        try Work.filter(Column("is_removed") == false).order(sql: "RANDOM()").fetchOne(db)
    }

    public static func work(_ productId: String) -> QueryInterfaceRequest<Work> {
        Work.filter(key: productId)
    }

    public static func tracks(of productId: String) -> QueryInterfaceRequest<Track> {
        Track.filter(Column("work_id") == productId).order(Column("file_path"))
    }

    public static func files(of productId: String) -> QueryInterfaceRequest<WorkFile> {
        WorkFile.filter(Column("work_id") == productId).order(Column("relative_path"))
    }
}
