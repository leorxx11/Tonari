import AppIntents
import TonariCore
import UIKit

/// A library work as Shortcuts and Siri see it.
nonisolated struct WorkEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "作品"
    static let defaultQuery = WorkEntityQuery()

    let id: String
    let title: String
    let cast: String?
    /// A small JPEG of the cover: Shortcuts and Siri run in other processes,
    /// which can't read the app's files.
    let cover: Data?

    init(_ work: Work) {
        id = work.productId
        title = work.displayTitle
        cast = work.castLine
        cover = work.mainImageLocalPath.flatMap {
            UIImage(contentsOfFile: URL.documentsDirectory.appending(path: $0).path)?
                .preparingThumbnail(of: CGSize(width: 240, height: 180))?
                .jpegData(compressionQuality: 0.7)
        }
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: cast.map { "\($0)" },
            image: cover.map { .init(data: $0) }
        )
    }
}

struct WorkEntityQuery: EntityStringQuery {
    @Dependency private var database: AppDatabase

    func entities(for identifiers: [WorkEntity.ID]) async throws -> [WorkEntity] {
        try await database.reader.read { try Work.fetchAll($0, keys: identifiers) }.map(WorkEntity.init)
    }

    /// The works played last, newest first.
    func suggestedEntities() async throws -> [WorkEntity] {
        try await database.reader.read { db in
            let ids = try CollectionQueries.recentlyPlayed(limit: 10, db).compactMap(\.workId)
            let works = try Work.filter(keys: ids).filter(Column("is_removed") == false).fetchAll(db)
            return ids.compactMap { id in works.first { $0.productId == id } }
        }
        .map(WorkEntity.init)
    }

    /// The library search's own matching, the first twenty hits.
    func entities(matching string: String) async throws -> [WorkEntity] {
        try await database.reader.read { db in
            try Work.filter(Column("is_removed") == false).fetchAll(db).filter { $0.matches(search: string) }.prefix(20)
        }
        .map(WorkEntity.init)
    }
}
