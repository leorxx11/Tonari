import Foundation
import TonariCore

/// The folder each work's track list shows once the user picks one; works
/// never picked open at `WorkTree.defaultAudioFolder`.
enum TrackFolderMemory {
    private static let key = "detail.trackFolders"

    static func folder(for productId: String) -> [String]? {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: [String]])?[productId]
    }

    static func remember(_ folder: [String], for productId: String) {
        var all = UserDefaults.standard.dictionary(forKey: key) ?? [:]
        all[productId] = folder
        UserDefaults.standard.set(all, forKey: key)
    }

    /// The remembered folder while it still holds audio, else the default.
    static func resolve(_ folders: [AudioFolder], tree: [WorkTreeNode], productId: String) -> AudioFolder? {
        let remembered = folder(for: productId)
        return folders.first { $0.path == remembered } ?? WorkTree.defaultAudioFolder(tree)
    }
}

extension PlaybackController {
    /// Picks a work up at its last track and position, or starts the folder
    /// its track list shows.
    func playWork(_ productId: String, database: AppDatabase) {
        let store = PlaybackStore(database: database)
        if let resume = try! store.resumePoint(for: productId) {
            play(resume.queue, at: resume.index, from: resume.queue.tracks[resume.index].lastPositionMs)
            return
        }
        let tracks = try! database.reader.read { try WorkQueries.tracks(of: productId).fetchAll($0) }
        let tree = WorkTree.build(tracks: tracks, files: [])
        let folder = TrackFolderMemory.resolve(WorkTree.audioFolders(tree), tree: tree, productId: productId)!
        play(try! store.queue(for: productId, folder: folder.path), at: 0)
    }
}
