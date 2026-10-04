import Foundation
import GRDB
import Testing
@testable import TonariCore

struct HomeQueriesTests {
    let database = try! AppDatabase.inMemory()
    let now = Fixtures.date

    private func work(_ id: String, played daysAgo: Int? = nil, added: Int = 0, actors: [String] = [], tags: [String] = []) -> Work {
        var work = Fixtures.work(id)
        work.lastPlayedAt = daysAgo.map { now.addingTimeInterval(-Double($0) * 86_400) }
        work.localImportedAt = now.addingTimeInterval(Double(added))
        work.voiceActors = actors
        work.genresJson = tags.map { Work.Genre(id: nil, name: $0) }
        return work
    }

    private func log(_ workId: String, daysAgo: Int, ms: Int) -> ListenLog {
        ListenLog(day: PlaybackStore.dayKey(now.addingTimeInterval(-Double(daysAgo) * 86_400)), workId: workId, listenedMs: ms)
    }

    @Test func forgottenSkipsRecentAndNeverPlayed() throws {
        try database.writer.write { db in
            try work("RJ1", played: 40).insert(db)
            try work("RJ2", played: 90).insert(db)
            try work("RJ3", played: 3).insert(db)
            try work("RJ4").insert(db)
        }
        let ids = try database.reader.read { try HomeQueries.forgotten(now: now, $0) }.map(\.productId)
        #expect(ids == ["RJ2", "RJ1"])
    }

    @Test func recentlyAddedNewestFirst() throws {
        try database.writer.write { db in
            try work("RJ1", added: 10).insert(db)
            try work("RJ2", added: 30).insert(db)
            try work("RJ3", added: 20).insert(db)
        }
        let ids = try database.reader.read { try HomeQueries.recentlyAdded(limit: 2, $0) }.map(\.productId)
        #expect(ids == ["RJ2", "RJ3"])
    }

    @Test func rankingUsesRecentListening() throws {
        try database.writer.write { db in
            try work("RJ1", actors: ["A", "B"], tags: ["囁き", "耳かき"]).insert(db)
            try work("RJ2", actors: ["B"], tags: ["耳かき"]).insert(db)
            try work("RJ3", actors: ["C"], tags: ["癒し", "耳かき"]).insert(db)
            try log("RJ1", daysAgo: 1, ms: 1000).insert(db)
            try log("RJ2", daysAgo: 2, ms: 500).insert(db)
            try log("RJ3", daysAgo: 60, ms: 9000).insert(db)
        }
        let actors = try database.reader.read { try HomeQueries.topVoiceActors(limit: 8, now: now, $0) }
        #expect(actors == ["B", "A"])
        let tags = try database.reader.read { try HomeQueries.tags(now: now, $0) }
        #expect(tags.map(\.name) == ["耳かき", "囁き", "癒し"])
        #expect(tags[0].count == 3 && tags[0].listenedMs == 1500)
    }

    @Test func randomNeedsEveryTag() throws {
        try database.writer.write { db in
            try work("RJ1", tags: ["囁き", "耳かき"]).insert(db)
            try work("RJ2", tags: ["耳かき"]).insert(db)
        }
        for _ in 0..<5 {
            #expect(try database.reader.read { try HomeQueries.random(tagged: ["囁き", "耳かき"], $0) }?.productId == "RJ1")
        }
        #expect(try database.reader.read { try HomeQueries.random(tagged: ["方言"], $0) } == nil)
    }

    @Test func continueListeningSkipsRemovedWorks() throws {
        try database.writer.write { db in
            var removed = work("RJ1")
            removed.isRemoved = true
            try removed.insert(db)
            try work("RJ2").insert(db)
            for (id, minutes) in [("RJ1", 1), ("RJ2", 5)] {
                try PlayHistoryEntry(
                    id: "work:\(id)", kind: "work", title: id, workId: id, sourceKind: nil, sourceId: nil, sourceName: nil,
                    path: nil, fileName: nil, pickcode: nil, size: nil, positionMs: 0, durationMs: nil,
                    playedAt: now.addingTimeInterval(-Double(minutes) * 60)
                ).insert(db)
            }
        }
        #expect(try database.reader.read(HomeQueries.continueListening)?.work.productId == "RJ2")
    }

    @Test func resumeOffersWhicheverCameLast() throws {
        func video(_ id: String, minutesAgo: Double, positionMs: Int) -> PlayHistoryEntry {
            PlayHistoryEntry(
                id: "p115:\(id)", kind: "video", title: id, workId: nil, sourceKind: "p115", sourceId: "p115", sourceName: "115 网盘",
                path: id, fileName: "\(id).mp4", pickcode: id, size: nil, positionMs: positionMs, durationMs: 600_000,
                playedAt: now.addingTimeInterval(-minutesAgo * 60)
            )
        }
        try database.writer.write { db in
            try work("RJ1").insert(db)
            try PlayHistoryEntry(
                id: "work:RJ1", kind: "work", title: "RJ1", workId: "RJ1", sourceKind: nil, sourceId: nil, sourceName: nil,
                path: nil, fileName: nil, pickcode: nil, size: nil, positionMs: 0, durationMs: nil,
                playedAt: now.addingTimeInterval(-5 * 60)
            ).insert(db)
            // Watched to the end, so there's nothing to pick up.
            try video("done", minutesAgo: 1, positionMs: 600_000).insert(db)
        }
        guard case .work(let work) = try database.reader.read(HomeQueries.resume) else { Issue.record("expected the work"); return }
        #expect(work.work.productId == "RJ1")

        try database.writer.write { try video("half", minutesAgo: 2, positionMs: 60_000).insert($0) }
        guard case .video(let progress) = try database.reader.read(HomeQueries.resume) else { Issue.record("expected the video"); return }
        #expect(progress.video.pickcode == "half")
    }
}
