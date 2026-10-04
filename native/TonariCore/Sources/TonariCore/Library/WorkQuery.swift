import Foundation
import GRDB

/// A field a library can be sorted by.
public protocol LibrarySortField: RawRepresentable<String>, CaseIterable, Hashable, Sendable {
    var label: String { get }
    /// Direction the field starts in when picked.
    var defaultDescending: Bool { get }
    var key: SQLExpression { get }
    /// Where the choice is kept.
    static var preferenceKey: String { get }
    /// The sort before anything was chosen.
    static var fallback: LibrarySort<Self> { get }
}

/// Persisted as `field:desc` / `field:asc`, the same format the Flutter
/// build used.
public struct LibrarySort<Field: LibrarySortField>: Equatable, Sendable {
    public static var preferenceKey: String { Field.preferenceKey }

    public var field: Field
    public var descending: Bool

    public init(field: Field, descending: Bool) {
        self.field = field
        self.descending = descending
    }

    public init(preference: String?) {
        let parts = (preference ?? "").split(separator: ":")
        guard let raw = parts.first, let field = Field(rawValue: String(raw)) else {
            self = Field.fallback
            return
        }
        self.init(field: field, descending: parts.last == "desc")
    }

    public var preference: String { "\(field.rawValue):\(descending ? "desc" : "asc")" }

    /// Picking the current field flips its direction; another field starts in
    /// its natural direction.
    public func selecting(_ field: Field) -> LibrarySort {
        field == self.field
            ? LibrarySort(field: field, descending: !descending)
            : LibrarySort(field: field, descending: field.defaultDescending)
    }

    /// SQLite sorts NULL lowest, so DESC already puts it last.
    var ordering: SQLOrderingTerm {
        descending ? field.key.desc : field.key.ascNullsLast
    }
}

public typealias WorkSort = LibrarySort<WorkSortField>
public typealias VideoSort = LibrarySort<VideoSortField>

public enum WorkSortField: String, LibrarySortField {
    case releaseDate, sales, rating, addedAt, lastPlayed, productId

    public static let preferenceKey = "library.sort.works"
    public static let fallback = WorkSort(field: .releaseDate, descending: true)

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

    /// Newest / highest first.
    public var defaultDescending: Bool { self != .productId }

    public var key: SQLExpression {
        switch self {
        case .releaseDate: Column("release_date").sqlExpression
        case .sales: Column("dl_count").sqlExpression
        case .rating: Column("rating").sqlExpression
        case .addedAt: Column("local_imported_at").sqlExpression
        case .lastPlayed: Column("last_played_at").sqlExpression
        case .productId: Column("product_id").sqlExpression
        }
    }
}

public enum VideoSortField: String, LibrarySortField {
    case addedAt, lastPlayed, title, size

    public static let preferenceKey = "library.sort.videos"
    public static let fallback = VideoSort(field: .addedAt, descending: true)

    public var label: String {
        switch self {
        case .addedAt: "收录时间"
        case .lastPlayed: "最近播放"
        case .title: "标题"
        case .size: "文件大小"
        }
    }

    /// Newest / largest first; titles A to Z.
    public var defaultDescending: Bool { self != .title }

    public var key: SQLExpression {
        switch self {
        case .addedAt: Column("added_at").sqlExpression
        case .lastPlayed: Column("last_played_at").sqlExpression
        // The shown title: the custom one, else the file name.
        case .title: SQL(sql: "COALESCE(custom_title, file_name)").sqlExpression
        case .size: Column("size").sqlExpression
        }
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

/// A voice actor, circle, series or tag a work carries; opens the works
/// that share it.
public struct WorkChip: Hashable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        case genre, voiceActor, series, circle, scenarioWriter, illustrator, musician

        public var label: String {
            switch self {
            case .genre: "标签"
            case .voiceActor: "声优"
            case .series: "系列"
            case .circle: "社团"
            case .scenarioWriter: "剧情"
            case .illustrator: "插画"
            case .musician: "音乐"
            }
        }
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
        case .scenarioWriter, .illustrator, .musician: "\(kind.label)：\(value)"
        }
    }

    public func matches(_ work: Work) -> Bool {
        switch kind {
        case .genre: work.genreNames.contains(value)
        case .voiceActor: work.voiceActors.contains(value)
        case .series: work.seriesName == value
        case .circle: work.circleName == value
        case .scenarioWriter: work.scenarioWriters.contains(value)
        case .illustrator: work.illustrators.contains(value)
        case .musician: work.musicians.contains(value)
        }
    }
}

extension Work {
    public var genreNames: [String] { genresJson.map(\.name) }

    public var displayTitle: String {
        if let titleZh, !titleZh.isEmpty { titleZh } else { title }
    }

    /// Search as the Flutter build did it: `#tag` looks at tag names only,
    /// anything else at every field a work is remembered by.
    public func matches(search query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        if query.hasPrefix("#") {
            let tag = query.dropFirst().trimmingCharacters(in: .whitespaces)
            return !tag.isEmpty && genreNames.contains { $0.lowercased().contains(tag) }
        }
        return !query.isEmpty && matchesText(query)
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

public struct MatchedSubtitle: Sendable, Hashable {
    public let trackId: String
    public let lineCount: Int
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
        return request.order(sort.ordering, Column("product_id"))
    }

    public static func remoteFolderIds(_ db: Database) throws -> Set<String> {
        try Set(String.fetchAll(db, ImportedFolder.filter(Column("type") != "local").select(Column("id"))))
    }

    public static func trackCounts(_ db: Database) throws -> [String: Int] {
        let rows = try Row.fetchAll(db, sql: "SELECT work_id, COUNT(*) AS count FROM tracks GROUP BY work_id")
        return Dictionary(uniqueKeysWithValues: rows.map { ($0["work_id"], $0["count"]) })
    }

    public static func subtitledTrackIds(of productId: String, _ db: Database) throws -> Set<String> {
        try Set(String.fetchAll(db, sql: """
            SELECT DISTINCT s.track_id FROM subtitles s JOIN tracks t ON t.id = s.track_id WHERE t.work_id = ?
            """, arguments: [productId]))
    }

    /// Each subtitle file matched to a track, keyed by the file's path.
    public static func matchedSubtitles(of productId: String, _ db: Database) throws -> [String: MatchedSubtitle] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT s.file_path, s.track_id, json_array_length(s.original_lines_json) AS count
            FROM subtitles s JOIN tracks t ON t.id = s.track_id WHERE t.work_id = ?
            """, arguments: [productId])
        return Dictionary(rows.map { ($0["file_path"], MatchedSubtitle(trackId: $0["track_id"], lineCount: $0["count"])) }, uniquingKeysWith: { $1 })
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

public enum VideoQueries {
    /// The video library: what the user kept, `local` being the copies
    /// imported from Files and `remote` the 115 ones.
    public static func library(sort: VideoSort, source: SourceFilter) -> QueryInterfaceRequest<VideoItem> {
        var request = VideoItem.all()
        let kind = Column("source_kind")
        switch source {
        case .all: break
        case .local: request = request.filter(kind == "local")
        case .remote: request = request.filter(kind != "local")
        }
        return request.order(sort.ordering, Column("id"))
    }
}
