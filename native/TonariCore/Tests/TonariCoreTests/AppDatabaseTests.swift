import Foundation
import GRDB
import Testing
@testable import TonariCore

struct AppDatabaseTests {
    @Test func freshDatabaseGetsSchema17() throws {
        let db = try AppDatabase.inMemory()
        let (version, tables) = try db.reader.read { db in
            (
                try AppDatabase.userVersion(db),
                try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")
            )
        }
        #expect(version == 17)
        #expect(tables == [
            "app_events", "collection_videos", "collection_works", "collections", "imported_folders",
            "listen_logs", "llm_providers", "play_history_entries", "subtitles", "tracks",
            "video_items", "webdav_servers", "work_files", "works",
        ])
    }

    @Test func reopeningKeepsData() throws {
        let dir = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try AppDatabase.open(in: dir).writer.write { try Fixtures.work("RJ01000001").insert($0) }
        let count = try AppDatabase.open(in: dir).reader.read { try Work.fetchCount($0) }
        #expect(count == 1)
    }

    @Test func recordsRoundTripInDriftEncoding() throws {
        let db = try AppDatabase.inMemory()
        var work = Fixtures.work("RJ01000001")
        work.voiceActors = ["柚木つばめ", "大山チロル"]
        work.genresJson = [.init(id: "500", name: "舔耳")]
        work.sampleImageLocalPaths = ["images/RJ01000001/smp1.jpg"]
        work.isFavorite = true
        let subtitle = Subtitle(
            id: "s1", trackId: "t1", filePath: "/a.srt", fileFormat: "srt", fileHash: "h", timeOffsetMs: 0,
            originalLinesJson: [.init(startMs: 100, endMs: 900, text: "こんにちは")], translatedLinesJson: nil,
            translatedAt: nil, translatedByModel: nil, createdAt: Fixtures.date, updatedAt: Fixtures.date
        )
        try db.writer.write { db in
            try work.insert(db)
            try subtitle.insert(db)
        }

        let raw = try db.reader.read { db in
            try Row.fetchOne(db, sql: """
                SELECT w.voice_actors, w.sample_image_local_paths, w.is_favorite, w.created_at, s.original_lines_json
                FROM works w, subtitles s
                """)!
        }
        #expect(raw["voice_actors"] as String == #"["柚木つばめ","大山チロル"]"#)
        #expect(raw["sample_image_local_paths"] as String == #"["images/RJ01000001/smp1.jpg"]"#)
        #expect(raw["is_favorite"] as Int64 == 1)
        #expect(raw["created_at"] as Int64 == Int64(Fixtures.date.timeIntervalSince1970))
        #expect((raw["original_lines_json"] as String).contains(#""t":"こんにちは""#))

        let fetched = try db.reader.read { try Work.fetchOne($0, key: "RJ01000001")! }
        #expect(fetched == work)
    }
}

enum Fixtures {
    static let date = Date(timeIntervalSince1970: 1_790_000_000)

    static func work(_ id: String) -> Work {
        Work(
            productId: id, title: "作品 \(id)", titleRomaji: nil, translatedTitle: nil, originalProductId: nil,
            circleId: nil, circleName: "社团", releaseDate: date, voiceActors: [], illustrators: [],
            scenarioWriters: [], musicians: [], ageRating: nil, workType: nil, workTypeName: nil, fileFormats: [],
            genresJson: [], fileSize: nil, seriesId: nil, seriesName: nil, descriptionHtml: nil, titleZh: nil,
            descriptionHtmlZh: nil, mainImageUrl: nil, sampleImageUrls: [], mainImageLocalPath: nil,
            sampleImageLocalPaths: [], descriptionImageLocalPaths: [], officialPrice: nil, currentPrice: nil,
            discountRate: nil, rating: nil, ratingCount: nil, dlCount: nil, wishlistCount: nil, reviewCount: nil,
            rankDay: nil, rankWeek: nil, rankMonth: nil, supportedLanguages: [], scrapedAt: nil,
            localImportedAt: date, localFolderPath: "/music/\(id)", importedFolderId: nil, lastPlayedAt: nil,
            lastPlayedTrackId: nil, isFavorite: false, isRemoved: false, needsRescan: false, userRating: nil,
            userTags: [], notes: nil, createdAt: date, updatedAt: date
        )
    }
}
