import Foundation
import GRDB

public struct Work: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "works"

    public struct Genre: Codable, Sendable, Hashable {
        public var id: String
        public var name: String
    }

    public var id: String { productId }

    public var productId: String
    public var title: String
    public var titleRomaji: String?
    public var translatedTitle: String?
    /// For a DLsite translation edition, the original release's RJ number.
    public var originalProductId: String?
    public var circleId: String?
    public var circleName: String?
    public var releaseDate: Date?
    public var voiceActors: [String]
    public var illustrators: [String]
    public var scenarioWriters: [String]
    public var musicians: [String]
    public var ageRating: String?
    public var workType: String?
    public var workTypeName: String?
    public var fileFormats: [String]
    public var genresJson: [Genre]
    public var fileSize: String?
    public var seriesId: String?
    public var seriesName: String?
    public var descriptionHtml: String?
    public var titleZh: String?
    public var descriptionHtmlZh: String?
    public var mainImageUrl: String?
    public var sampleImageUrls: [String]
    /// Paths relative to Documents, e.g. `images/RJ01234567/main.jpg`.
    public var mainImageLocalPath: String?
    public var sampleImageLocalPaths: [String]
    public var descriptionImageLocalPaths: [String]
    public var officialPrice: Int?
    public var currentPrice: Int?
    public var discountRate: Int?
    public var rating: Double?
    public var ratingCount: Int?
    public var dlCount: Int?
    public var wishlistCount: Int?
    public var reviewCount: Int?
    public var rankDay: Int?
    public var rankWeek: Int?
    public var rankMonth: Int?
    public var supportedLanguages: [String]
    public var scrapedAt: Date?
    public var localImportedAt: Date
    public var localFolderPath: String
    public var importedFolderId: String?
    public var lastPlayedAt: Date?
    public var lastPlayedTrackId: String?
    public var isFavorite: Bool
    /// Tombstone: the work's snapshot was cleared and folder rescans skip it.
    public var isRemoved: Bool
    public var needsRescan: Bool
    public var userRating: Int?
    public var userTags: [String]
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date
}
