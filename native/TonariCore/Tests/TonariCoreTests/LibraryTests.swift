import Foundation
import GRDB
import Testing
@testable import TonariCore

struct WorkFilterTests {
    private func work(_ id: String, configure: (inout Work) -> Void = { _ in }) -> Work {
        var work = Fixtures.work(id)
        configure(&work)
        return work
    }

    @Test func textSearchCoversTitlesCastAndTags() {
        let w = work("RJ01098024") {
            $0.titleZh = "双重分身惩罚"
            $0.voiceActors = ["大山チロル"]
            $0.genresJson = [.init(id: "500", name: "舔耳")]
        }
        for query in ["rj0109", "分身", "チロル", "舔耳", "社团"] {
            var filter = WorkFilter()
            filter.searchText = query
            #expect(filter.matches(w), "\(query)")
        }
        var miss = WorkFilter()
        miss.searchText = "不存在"
        #expect(!miss.matches(w))
    }

    @Test func hashSearchMatchesTagsOnly() {
        let w = work("RJ01000001") {
            $0.title = "舔耳 in title"
            $0.genresJson = [.init(id: "1", name: "ASMR")]
        }
        var filter = WorkFilter()
        filter.searchText = "#asm"
        #expect(filter.matches(w))
        filter.searchText = "#舔耳"
        #expect(!filter.matches(w))
    }

    @Test func chipsMustAllMatch() {
        let w = work("RJ01000001") { $0.voiceActors = ["A", "B"] }
        var filter = WorkFilter()
        filter.add(WorkChip(.voiceActor, "A"))
        filter.add(WorkChip(.voiceActor, "A"))
        #expect(filter.chips.count == 1)
        #expect(filter.matches(w))
        filter.add(WorkChip(.circle, "别的社团"))
        #expect(!filter.matches(w))
    }

    @Test func sortPreferenceRoundTripsAndToggles() {
        #expect(WorkSort(preference: "releaseDate:desc") == WorkSort(field: .releaseDate, descending: true))
        #expect(WorkSort(preference: "productId:asc").preference == "productId:asc")
        #expect(WorkSort(preference: nil) == WorkSort(field: .releaseDate, descending: true))
        let sort = WorkSort(field: .rating, descending: true)
        #expect(sort.selecting(.rating) == WorkSort(field: .rating, descending: false))
        #expect(sort.selecting(.productId) == WorkSort(field: .productId, descending: false))
    }
}

struct WorkQueryTests {
    @Test func orderingPutsMissingValuesLastAndFiltersSources() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            let now = Date.now
            try ImportedFolder(id: "remote", displayName: "115", bookmarkBase64: "", type: "p115", serverId: nil, remotePath: "0", createdAt: now, updatedAt: now).insert(db)
            var a = Fixtures.work("RJ01000001"); a.rating = 4.5
            var b = Fixtures.work("RJ01000002"); b.rating = nil; b.importedFolderId = "remote"
            var c = Fixtures.work("RJ01000003"); c.rating = 3.0
            var removed = Fixtures.work("RJ01000004"); removed.isRemoved = true
            for w in [a, b, c, removed] { try w.insert(db) }
        }
        func ids(_ sort: WorkSort, _ source: SourceFilter) throws -> [String] {
            try db.reader.read { try WorkQueries.library(sort: sort, source: source).fetchAll($0).map(\.productId) }
        }
        #expect(try ids(WorkSort(field: .rating, descending: true), .all) == ["RJ01000001", "RJ01000003", "RJ01000002"])
        #expect(try ids(WorkSort(field: .rating, descending: false), .all) == ["RJ01000003", "RJ01000001", "RJ01000002"])
        #expect(try ids(WorkSort(field: .productId, descending: false), .remote) == ["RJ01000002"])
        #expect(try ids(WorkSort(field: .productId, descending: false), .local) == ["RJ01000001", "RJ01000003"])
    }

    @Test func collectionsAndFavorites() throws {
        let db = try AppDatabase.inMemory()
        try db.writer.write { try Fixtures.work("RJ01000001").insert($0) }
        try db.setFavorite("RJ01000001", true)
        let id = try db.createCollection(named: "睡前")
        try db.setMembership(work: "RJ01000001", collection: id, member: true)
        try db.setMembership(work: "RJ01000001", collection: id, member: true)

        let (favorites, summaries, containing) = try db.reader.read { db in
            (
                try CollectionQueries.favoriteWorks(db),
                try CollectionQueries.summaries(db),
                try CollectionQueries.collectionIds(containing: "RJ01000001", db)
            )
        }
        #expect(favorites.map(\.productId) == ["RJ01000001"])
        #expect(summaries.map(\.workCount) == [1])
        #expect(containing == [id])

        try db.deleteCollection(id)
        #expect(try db.reader.read { try CollectionWork.fetchCount($0) } == 0)
        #expect(try db.reader.read { try Work.fetchCount($0) } == 1)
    }
}

struct WorkTreeTests {
    private func track(_ path: String, bytes: Int) -> Track {
        Track(
            id: path, workId: "RJ", filePath: "/x/\(path)", relativePath: path,
            fileName: String(path.split(separator: "/").last!), fileFormat: "mp3", fileSizeBytes: bytes,
            durationMs: 1000, sampleRate: nil, bitRate: nil, categoryHint: nil, userCategory: nil,
            parentDirName: "", trackNumber: nil, title: String(path.split(separator: "/").last!),
            alternateQualityPathsJson: [:], lastPositionMs: 0, playCount: 0,
            createdAt: Fixtures.date, updatedAt: Fixtures.date, titleZh: nil
        )
    }

    @Test func naturalOrderComparesDigitRunsNumerically() {
        let names = ["10_end.mp3", "2_mid.mp3", "01_start.mp3", "b.mp3", "a.mp3"]
        #expect(names.sorted(by: NaturalOrder.less) == ["01_start.mp3", "2_mid.mp3", "10_end.mp3", "a.mp3", "b.mp3"])
    }

    @Test func buildsFoldersFirstThenFiles() {
        let tree = WorkTree.build(
            tracks: [track("mp3/10.mp3", bytes: 1), track("mp3/2.mp3", bytes: 1), track("root.mp3", bytes: 1)],
            files: []
        )
        #expect(tree.map(\.name) == ["mp3", "root.mp3"])
        #expect(tree[0].children.map(\.name) == ["2.mp3", "10.mp3"])
        #expect(WorkTree.playbackOrder(tree).map(\.fileName) == ["2.mp3", "10.mp3", "root.mp3"])
    }

    @Test func autoPathDescendsIntoDominantFolder() {
        let tree = WorkTree.build(
            tracks: [
                track("本編/WAV/1.wav", bytes: 700), track("本編/MP3/1.mp3", bytes: 70),
                track("特典/1.mp3", bytes: 30),
            ],
            files: []
        )
        #expect(WorkTree.autoPath(tree) == ["本編", "WAV"])

        let split = WorkTree.build(tracks: [track("SEあり/1.wav", bytes: 50), track("SEなし/1.wav", bytes: 50)], files: [])
        #expect(WorkTree.autoPath(split).isEmpty)
    }
}

struct WorkDescriptionTests {
    @Test func splitsTextAndImages() throws {
        let html = """
            <p>第一段<br>第二行</p>
            <h3>トラックリスト</h3>
            <img src="//img.dlsite.jp/a.jpg">
            <div>后记 &amp; 感谢</div><script>x()</script>
            """
        let items = try WorkDescription.parse(html)
        #expect(items == [
            .text([.paragraph("第一段\n第二行"), .heading("トラックリスト")]),
            .image(url: "https://img.dlsite.jp/a.jpg"),
            .text([.paragraph("后记 & 感谢")]),
        ])
        #expect(WorkDescription.imageURLs(items) == ["https://img.dlsite.jp/a.jpg"])
    }

    @Test func carriageReturnsAreNewlines() throws {
        #expect(try WorkDescription.parse("<p>一\r\n<br />\r\n二</p>") == [.text([.paragraph("一\n\n二")])])
    }
}

struct LibraryStatsTests {
    @Test func ranksByCountThenName() {
        var a = Fixtures.work("RJ1"); a.voiceActors = ["B", "A"]
        var b = Fixtures.work("RJ2"); b.voiceActors = ["B"]
        let stats = LibraryStats([a, b])
        #expect(stats.voiceActors.map(\.name) == ["B", "A"])
        #expect(stats.circles == [.init(name: "社团", count: 2)])
    }
}
