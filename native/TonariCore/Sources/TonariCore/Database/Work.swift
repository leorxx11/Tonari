import Foundation
import GRDB

/// Row of the `works` table, whose schema is inherited from the Flutter
/// build's Drift database: snake_case columns, dates as Unix seconds, string
/// lists as JSON text.
public struct Work: Codable, Identifiable, Sendable, FetchableRecord, TableRecord {
    public static let databaseTableName = "works"
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    public static let databaseDateDecodingStrategy = DatabaseDateDecodingStrategy.timeIntervalSince1970

    public var id: String { productId }

    public var productId: String
    public var title: String
    public var circleName: String?
    public var releaseDate: Date?
    public var voiceActors: [String]
    public var rating: Double?
    public var mainImageLocalPath: String?
    public var localImportedAt: Date
    public var isFavorite: Bool
    public var isRemoved: Bool
}
