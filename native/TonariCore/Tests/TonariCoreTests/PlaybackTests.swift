import Foundation
import GRDB
import Testing
@testable import TonariCore

struct PlaybackModeTests {
    @Test func sequenceStopsAtTheEnd() {
        var rng = SystemRandomNumberGenerator()
        #expect(PlaybackMode.sequence.indexAfterCompletion(current: 0, count: 3, using: &rng) == 1)
        #expect(PlaybackMode.sequence.indexAfterCompletion(current: 2, count: 3, using: &rng) == nil)
        #expect(PlaybackMode.loopAll.indexAfterCompletion(current: 2, count: 3, using: &rng) == 0)
        #expect(PlaybackMode.loopOne.indexAfterCompletion(current: 1, count: 3, using: &rng) == 1)
    }

    @Test func shuffleNeverRepeatsTheCurrentTrack() {
        for current in 0..<4 {
            for _ in 0..<50 {
                var rng = SystemRandomNumberGenerator()
                let next = PlaybackMode.shuffle.indexAfterCompletion(current: current, count: 4, using: &rng)!
                #expect(next != current && (0..<4).contains(next))
            }
        }
        var rng = SystemRandomNumberGenerator()
        #expect(PlaybackMode.shuffle.indexAfterCompletion(current: 0, count: 1, using: &rng) == 0)
    }

    @Test func modesCycleInTheFlutterOrder() {
        #expect(PlaybackMode.allCases.map(\.next) == [.loopAll, .loopOne, .shuffle, .sequence])
        #expect(PlaybackMode(rawValue: "loopOne") == .loopOne)
    }
}

struct PlaybackStoreTests {
    private func database() throws -> (AppDatabase, PlaybackStore) {
        let database = try AppDatabase.inMemory()
        try database.writer.write { db in
            try Fixtures.work("RJ01000001").insert(db)
            for (id, path) in [("t2", "/music/RJ01000001/02.mp3"), ("t1", "/music/RJ01000001/01.mp3")] {
                try Track(
                    id: id, workId: "RJ01000001", filePath: path, relativePath: String(path.split(separator: "/").last!),
                    fileName: String(path.split(separator: "/").last!), fileFormat: "mp3", fileSizeBytes: 1, durationMs: 0,
                    sampleRate: nil, bitRate: nil, categoryHint: nil, userCategory: nil, parentDirName: "RJ01000001",
                    trackNumber: nil, title: id, alternateQualityPathsJson: [:], lastPositionMs: 0, playCount: 0,
                    createdAt: Fixtures.date, updatedAt: Fixtures.date, titleZh: nil
                ).insert(db)
            }
        }
        return (database, PlaybackStore(database: database))
    }

    @Test func restoresTheLastPlayedTrackInPlaybackOrder() throws {
        let (database, store) = try database()
        #expect(try store.lastPlayed() == nil)
        let queue = try store.queue(for: "RJ01000001", folder: [])
        #expect(queue.tracks.map(\.id) == ["t1", "t2"])
        try store.trackStarted(queue.tracks[1], of: queue.work, at: Fixtures.date)
        try store.savePosition(42_000, of: queue.tracks[1], in: queue.work, at: Fixtures.date)
        guard case .work(let restored, let index) = try store.lastPlayed() else { Issue.record("no work restored"); return }
        #expect(index == 1)
        #expect(restored.tracks[1].lastPositionMs == 42_000)
        let history = try database.reader.read { try PlayHistoryEntry.fetchAll($0) }
        #expect(history.map(\.id) == ["work:RJ01000001"])
    }

    @Test func accumulatesListeningPerDayAndWork() throws {
        let (database, store) = try database()
        try store.addListening(5_000, to: "RJ01000001", at: Fixtures.date)
        try store.addListening(4_000, to: "RJ01000001", at: Fixtures.date)
        let logs = try database.reader.read { try ListenLog.fetchAll($0) }
        #expect(logs.map(\.listenedMs) == [9_000])
        #expect(logs[0].day == PlaybackStore.dayKey(Fixtures.date))
    }

    @Test func keysRemoteFilesByPickcode() throws {
        let (database, store) = try database()
        let entry = RemoteEntry(id: "1", path: "1", name: "01 本編.mp3", kind: .audio, size: 10, pickcode: "abc", sourceId: P115Client.sourceId)
        try store.recordFile(entry, sourceName: "115 网盘")
        try store.recordFile(entry, sourceName: "115 网盘")
        let rows = try database.reader.read { try PlayHistoryEntry.fetchAll($0) }
        #expect(rows.map(\.id) == ["p115:abc"])
        #expect(rows[0].title == "01 本編" && rows[0].kind == "audio" && rows[0].sourceKind == "p115")
    }

    @Test func restoresAFilePlayedAfterAWork() throws {
        let (_, store) = try database()
        let queue = try store.queue(for: "RJ01000001", folder: [])
        try store.trackStarted(queue.tracks[0], of: queue.work, at: Fixtures.date)
        let entry = RemoteEntry(id: "9", path: "9", name: "a.mp3", kind: .audio, size: 10, pickcode: "pc", sourceId: P115Client.sourceId)
        try store.recordFile(entry, sourceName: "115 网盘", at: Fixtures.date.addingTimeInterval(1))
        try store.saveFilePosition(7_000, durationMs: 60_000, of: entry, at: Fixtures.date.addingTimeInterval(2))
        guard case .file(let file, let sourceName, let positionMs, let durationMs) = try store.lastPlayed() else {
            Issue.record("no file restored")
            return
        }
        #expect(file.pickcode == "pc" && file.name == "a.mp3" && sourceName == "115 网盘")
        #expect(positionMs == 7_000 && durationMs == 60_000)
    }

    @Test func videosResumeWhereTheyWereLeftUnlessFinished() throws {
        let (database, store) = try database()
        let entry = RemoteEntry(id: "v", path: "v", name: "第4章.mkv", kind: .video, size: 10, pickcode: "vpc", sourceId: P115Client.sourceId)
        let video = PlayableVideo(p115: entry, sourceName: "115 网盘")
        #expect(video.id == "p115:vpc")
        #expect(try store.videoResumeMs(video) == 0)
        try store.recordVideo(video, at: Fixtures.date)
        try store.saveVideoPosition(600_000, durationMs: 2_000_000, of: video)
        try store.recordVideo(video, at: Fixtures.date.addingTimeInterval(60))
        #expect(try store.videoResumeMs(video) == 600_000)
        #expect(try store.continueWatching(limit: 5).map(\.video) == [video])
        #expect(try store.lastPlayed() == nil)
        #expect(try store.lastPlayedVideo()?.video == video)
        let row = try database.reader.read { try PlayHistoryEntry.fetchOne($0, key: "p115:vpc")! }
        #expect(row.remoteFile == nil)

        try store.saveVideoPosition(1_995_000, durationMs: 2_000_000, of: video)
        #expect(try store.videoResumeMs(video) == 0)
        #expect(try store.continueWatching(limit: 5).isEmpty)
    }

    @Test func videoLibraryAddsRenamesGroupsAndRemoves() throws {
        let (database, _) = try database()
        let video = PlayableVideo(localPath: "videos/abc/clip.mp4", fileName: "clip.mp4", size: 5)
        #expect(video.id == "local:video_import:videos/abc/clip.mp4")
        try database.addVideo(video)
        try database.addVideo(video)
        try database.renameVideo(video.id, to: "  ")
        try database.setVideoCover(video.id, path: "video_covers/x.png")
        let group = try database.createCollection(named: "睡前")
        try database.setMembership(video: video.id, collection: group, member: true)
        let item = try database.reader.read { try VideoItem.fetchOne($0, key: video.id)! }
        #expect(item.customTitle == nil && item.coverPath == "video_covers/x.png")
        #expect(PlayableVideo(item) == video)
        #expect(try database.reader.read { try CollectionQueries.collectionIds(containingVideo: video.id, $0) } == [group])

        try database.removeVideo(video.id)
        #expect(try database.reader.read { try VideoItem.fetchCount($0) } == 0)
        #expect(try database.reader.read { try CollectionVideo.fetchCount($0) } == 0)
    }

    @Test func countsCompletionsAndLearnsDurations() throws {
        let (database, store) = try database()
        let track = try store.queue(for: "RJ01000001", folder: []).tracks[0]
        try store.trackCompleted(track)
        try store.recordDuration(61_000, of: track)
        let row = try database.reader.read { try Track.fetchOne($0, key: track.id)! }
        #expect(row.playCount == 1 && row.durationMs == 61_000)
    }
}

struct SubtitleTimelineTests {
    private func subtitle(offset: Int = 0) -> Subtitle {
        Subtitle(
            id: "t1", trackId: "t1", filePath: "a.srt", fileFormat: "srt", fileHash: "", timeOffsetMs: offset,
            originalLinesJson: [.init(startMs: 1_000, endMs: 2_000, text: "一"), .init(startMs: 5_000, endMs: 6_000, text: "二")],
            translatedLinesJson: nil, translatedAt: nil, translatedByModel: nil, createdAt: Fixtures.date, updatedAt: Fixtures.date
        )
    }

    @Test func keepsTheLastStartedLineThroughGaps() {
        let s = subtitle()
        #expect(s.lineIndex(at: 500) == nil)
        #expect(s.lineIndex(at: 1_000) == 0)
        #expect(s.lineIndex(at: 3_000) == 0)
        #expect(s.lineIndex(at: 9_000) == 1)
    }

    @Test func offsetDelaysLinesBothWays() {
        let delayed = subtitle(offset: 500)
        #expect(delayed.lineIndex(at: 1_200) == nil)
        #expect(delayed.positionMs(ofLine: 1) == 5_500)
        #expect(subtitle(offset: -2_000).positionMs(ofLine: 0) == 0)
    }
}

struct ListenStatsTests {
    @Test func sumsPeriodsDaysAndRankings() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        // Wednesday 2026-09-23 local time.
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 21))!
        var a = Fixtures.work("RJ01000001")
        a.voiceActors = ["甲", "乙"]
        a.circleName = "社团A"
        var b = Fixtures.work("RJ01000002")
        b.voiceActors = ["甲"]
        b.circleName = nil
        let logs = [
            ListenLog(day: "2026-09-23", workId: a.productId, listenedMs: 60_000),
            ListenLog(day: "2026-09-21", workId: b.productId, listenedMs: 30_000),
            ListenLog(day: "2026-09-20", workId: a.productId, listenedMs: 10_000),
            ListenLog(day: "2026-08-31", workId: b.productId, listenedMs: 5_000),
            ListenLog(day: "2026-09-22", workId: "RJ09999999", listenedMs: 1_000),
        ]
        let stats = ListenStats.compute(logs: logs, works: [a.productId: a, b.productId: b], now: now, calendar: calendar)
        #expect(stats.totalMs == 106_000)
        #expect(stats.weekMs == 91_000)
        #expect(stats.monthMs == 101_000)
        #expect(stats.daily.count == ListenStats.dailyWindow)
        #expect(stats.daily.last?.ms == 60_000)
        #expect(stats.daily[ListenStats.dailyWindow - 3].ms == 30_000)
        #expect(stats.topWorks.map(\.item.productId) == ["RJ01000001", "RJ01000002"])
        #expect(stats.topVoiceActors.map(\.item) == ["甲", "乙"])
        #expect(stats.topVoiceActors[0].ms == 105_000)
        #expect(stats.topCircles.map(\.item) == ["社团A"])
    }
}
