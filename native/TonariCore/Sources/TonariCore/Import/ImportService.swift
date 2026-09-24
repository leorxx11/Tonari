import CryptoKit
import Foundation
import GRDB

public struct ImportSummary: Sendable {
    public var worksInserted = 0
    public var worksUpdated = 0
    public var tracksTotal = 0
    public var workIds: Set<String> = []
    /// Skipped because their scan was incomplete; the user can retry later.
    public var incompleteWorks: [String] = []
    /// Already in the library and left untouched (`skipExisting`).
    public var worksSkipped = 0

    public var resultText: String {
        var text = "导入完成：新增 \(worksInserted)，已有 \(worksSkipped) 跳过，共 \(tracksTotal) 音轨。封面和元数据后台补全中。"
        if !incompleteWorks.isEmpty {
            text += "\n\(incompleteWorks.count) 个作品扫描失败，已跳过，可稍后重新导入。"
        }
        return text
    }
}

extension AppDatabase {
    /// Writes a scan into the library; idempotent for the same input. A
    /// rescan adds new files, prunes vanished ones per work, and keeps each
    /// track's position and play count.
    ///
    /// - `reviveTombstoned`: an explicit single-work reimport brings back a
    ///   removed work; a folder import never does.
    /// - `skipExisting`: leave works already in the library untouched.
    /// - `remoteSubtitles`: for remote sources, the subtitle bytes that were
    ///   downloaded, keyed by file path; nil reads local files from disk.
    public func applyScanResult(
        _ scan: ScanResult,
        sourceFolderId: String?,
        reviveTombstoned: Bool = false,
        skipExisting: Bool = false,
        remoteSubtitles: [String: Data]? = nil
    ) throws -> ImportSummary {
        var summary = ImportSummary()
        let skip: Set<String> = skipExisting ? try activeWorkIds(among: scan.works.map(\.productId)) : []
        summary.worksSkipped = skip.count + scan.skippedExisting
        // File IO outside the write transaction.
        let subtitles = scan.works.filter { !skip.contains($0.productId) && !$0.incomplete }
            .flatMap { Self.readSubtitles($0, remote: remoteSubtitles) }
        let now = Date.now

        try writer.write { db in
            for scanned in scan.works {
                if scanned.incomplete {
                    summary.incompleteWorks.append(scanned.productId)
                    continue
                }
                if skip.contains(scanned.productId) { continue }
                let id = scanned.productId
                let existing = try Work.fetchOne(db, key: id)
                if let existing, existing.isRemoved, !reviveTombstoned { continue }
                summary.workIds.insert(id)

                if existing == nil {
                    try Work.shell(id, folderPath: scanned.rootPath, folderId: sourceFolderId, at: now).insert(db)
                    summary.worksInserted += 1
                } else {
                    try db.execute(sql: """
                        UPDATE works SET local_folder_path = ?, updated_at = ?, imported_folder_id = ?, needs_rescan = 0,
                        is_removed = CASE WHEN ? THEN 0 ELSE is_removed END WHERE product_id = ?
                        """, arguments: [scanned.rootPath, now.unixSeconds, sourceFolderId, reviveTombstoned, id])
                    summary.worksUpdated += 1
                }

                var trackIds: [String] = []
                for audio in scanned.files(.audio) {
                    let trackId = Self.fileId(id, audio.relativePath)
                    trackIds.append(trackId)
                    let title = (audio.fileName as NSString).deletingPathExtension
                    let hint = audio.categoryHint
                    if try Track.exists(db, key: trackId) {
                        try db.execute(sql: """
                            UPDATE tracks SET file_path = ?, relative_path = ?, file_name = ?, file_format = ?,
                            file_size_bytes = ?, parent_dir_name = ?, title = ?, category_hint = ?, updated_at = ? WHERE id = ?
                            """, arguments: [audio.path, audio.relativePath, audio.fileName, FileKind.ext(audio.fileName),
                                             audio.sizeBytes, audio.parentDirName, title, hint, now.unixSeconds, trackId])
                    } else {
                        try Track(
                            id: trackId, workId: id, filePath: audio.path, relativePath: audio.relativePath,
                            fileName: audio.fileName, fileFormat: FileKind.ext(audio.fileName), fileSizeBytes: audio.sizeBytes,
                            durationMs: 0, sampleRate: nil, bitRate: nil, categoryHint: hint, userCategory: nil,
                            parentDirName: audio.parentDirName, trackNumber: nil, title: title,
                            alternateQualityPathsJson: [:], lastPositionMs: 0, playCount: 0,
                            createdAt: now, updatedAt: now, titleZh: nil
                        ).insert(db)
                    }
                    summary.tracksTotal += 1
                }
                try Track.filter(Column("work_id") == id && !trackIds.contains(Column("id"))).deleteAll(db)

                // A subtitle row shares its track's id; upserting keeps the
                // user's time offset and any translation.
                var subtitleIds: [String] = []
                for parsed in subtitles where parsed.workId == id {
                    let trackId = Self.fileId(id, parsed.audioRelativePath)
                    guard trackIds.contains(trackId) else { continue }
                    subtitleIds.append(trackId)
                    if var row = try Subtitle.fetchOne(db, key: trackId) {
                        row.filePath = parsed.path
                        row.fileFormat = parsed.format
                        row.fileHash = parsed.hash
                        row.originalLinesJson = parsed.lines
                        row.updatedAt = now
                        try row.update(db)
                    } else {
                        try Subtitle(
                            id: trackId, trackId: trackId, filePath: parsed.path, fileFormat: parsed.format,
                            fileHash: parsed.hash, timeOffsetMs: 0, originalLinesJson: parsed.lines,
                            translatedLinesJson: nil, translatedAt: nil, translatedByModel: nil,
                            createdAt: now, updatedAt: now
                        ).insert(db)
                    }
                }
                try Subtitle.filter(trackIds.contains(Column("track_id")) && !subtitleIds.contains(Column("id"))).deleteAll(db)

                // Everything that isn't audio, so the folder tree can be drawn.
                var fileIds: [String] = []
                for file in scanned.files where file.kind != .audio {
                    let fileId = Self.fileId(id, file.relativePath)
                    fileIds.append(fileId)
                    if try WorkFile.exists(db, key: fileId) {
                        try db.execute(sql: """
                            UPDATE work_files SET file_path = ?, file_name = ?, file_kind = ?, file_size_bytes = ?, updated_at = ?
                            WHERE id = ?
                            """, arguments: [file.path, file.fileName, file.kind.rawValue, file.sizeBytes, now.unixSeconds, fileId])
                    } else {
                        try WorkFile(
                            id: fileId, workId: id, filePath: file.path, relativePath: file.relativePath,
                            fileName: file.fileName, fileKind: file.kind.rawValue, fileSizeBytes: file.sizeBytes,
                            createdAt: now, updatedAt: now
                        ).insert(db)
                    }
                }
                try WorkFile.filter(Column("work_id") == id && !fileIds.contains(Column("id"))).deleteAll(db)
            }
        }
        return summary
    }

    /// Non-removed works among `ids`.
    public func activeWorkIds(among ids: [String]) throws -> Set<String> {
        try reader.read { db in
            try Set(String.fetchAll(db, Work.filter(keys: ids).filter(Column("is_removed") == false).select(Column("product_id"))))
        }
    }

    /// Stable across rescans for the same logical file.
    static func fileId(_ workId: String, _ relativePath: String) -> String {
        "\(workId)|\(relativePath.lowercased())"
    }

    private struct ParsedSubtitle {
        let workId: String
        let audioRelativePath: String
        let path: String
        let format: String
        let hash: String
        let lines: [Subtitle.Line]
    }

    /// Subtitles matched to audio in the same folder, named either
    /// `track.wav.vtt` (DLsite style) or `track.srt` (shared stem).
    private static func readSubtitles(_ work: ScannedWork, remote: [String: Data]?) -> [ParsedSubtitle] {
        let audios = work.files(.audio)
        func dir(_ relativePath: String) -> String { (relativePath as NSString).deletingLastPathComponent }
        return work.files(.subtitle).compactMap { subtitle in
            let format = FileKind.ext(subtitle.fileName)
            guard SubtitleParser.supports(format) else { return nil }
            let stem = (subtitle.fileName as NSString).deletingPathExtension
            guard let audio = audios.first(where: {
                dir($0.relativePath) == dir(subtitle.relativePath)
                    && ($0.fileName == stem || ($0.fileName as NSString).deletingPathExtension == stem)
            }) else { return nil }
            let data: Data
            if let remote {
                guard let downloaded = remote[subtitle.path] else { return nil }
                data = downloaded
            } else {
                do {
                    data = try Data(contentsOf: URL(filePath: subtitle.path))
                } catch {
                    DiagnosticLog.shared.write("import", "subtitle_unreadable", ["path": subtitle.path, "error": "\(error)"])
                    return nil
                }
            }
            let body = data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data[...]
            let lines = SubtitleParser.parse(String(decoding: body, as: UTF8.self), format: format)
            guard !lines.isEmpty else { return nil }
            return ParsedSubtitle(
                workId: work.productId, audioRelativePath: audio.relativePath, path: subtitle.path, format: format,
                hash: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), lines: lines
            )
        }
    }
}

extension Work {
    /// A freshly imported work before its DLsite metadata is fetched.
    static func shell(_ productId: String, folderPath: String, folderId: String?, at now: Date) -> Work {
        Work(
            productId: productId, title: productId, titleRomaji: nil, translatedTitle: nil, originalProductId: nil,
            circleId: nil, circleName: nil, releaseDate: nil, voiceActors: [], illustrators: [], scenarioWriters: [],
            musicians: [], ageRating: nil, workType: nil, workTypeName: nil, fileFormats: [], genresJson: [],
            fileSize: nil, seriesId: nil, seriesName: nil, descriptionHtml: nil, titleZh: nil, descriptionHtmlZh: nil,
            mainImageUrl: nil, sampleImageUrls: [], mainImageLocalPath: nil, sampleImageLocalPaths: [],
            descriptionImageLocalPaths: [], officialPrice: nil, currentPrice: nil, discountRate: nil, rating: nil,
            ratingCount: nil, dlCount: nil, wishlistCount: nil, reviewCount: nil, rankDay: nil, rankWeek: nil,
            rankMonth: nil, supportedLanguages: [], scrapedAt: nil, localImportedAt: now, localFolderPath: folderPath,
            importedFolderId: folderId, lastPlayedAt: nil, lastPlayedTrackId: nil, isFavorite: false, isRemoved: false,
            needsRescan: false, userRating: nil, userTags: [], notes: nil, createdAt: now, updatedAt: now
        )
    }
}
