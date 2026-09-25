import Foundation

/// A work's files mirrored as folders, split on `/` in their relative paths.
public indirect enum WorkTreeNode: Sendable, Identifiable {
    case folder(name: String, children: [WorkTreeNode])
    case track(Track)
    case file(WorkFile)

    public var id: String {
        switch self {
        case .folder(let name, _): "folder:\(name)"
        case .track(let track): "track:\(track.id)"
        case .file(let file): "file:\(file.id)"
        }
    }

    public var name: String {
        switch self {
        case .folder(let name, _): name
        case .track(let track): track.title
        case .file(let file): file.fileName
        }
    }

    public var children: [WorkTreeNode] {
        if case .folder(_, let children) = self { children } else { [] }
    }

    public var audioCount: Int {
        switch self {
        case .folder(_, let children): children.reduce(0) { $0 + $1.audioCount }
        case .track: 1
        case .file: 0
        }
    }

    public var totalDurationMs: Int {
        switch self {
        case .folder(_, let children): children.reduce(0) { $0 + $1.totalDurationMs }
        case .track(let track): track.durationMs
        case .file: 0
        }
    }

    var audioBytes: Int {
        switch self {
        case .folder(_, let children): children.reduce(0) { $0 + $1.audioBytes }
        case .track(let track): track.fileSizeBytes
        case .file: 0
        }
    }
}

public enum WorkTree {
    /// At each level folders come before files; each group is in natural
    /// order, so `2_xxx` sorts before `10_xxx`.
    public static func build(tracks: [Track], files: [WorkFile]) -> [WorkTreeNode] {
        final class Level {
            var folders: [String: Level] = [:]
            var leaves: [String: WorkTreeNode] = [:]
        }
        let root = Level()
        func insert(_ relativePath: String, fallbackName: String, _ leaf: WorkTreeNode) {
            let parts = relativePath.isEmpty ? [fallbackName] : relativePath.split(separator: "/").map(String.init)
            var level = root
            for part in parts.dropLast() {
                if level.folders[part] == nil { level.folders[part] = Level() }
                level = level.folders[part]!
            }
            level.leaves[parts.last!] = leaf
        }
        for track in tracks { insert(track.relativePath, fallbackName: track.fileName, .track(track)) }
        for file in files { insert(file.relativePath, fallbackName: file.fileName, .file(file)) }

        func materialize(_ level: Level) -> [WorkTreeNode] {
            let folders = level.folders.keys.sorted(by: NaturalOrder.less).map {
                WorkTreeNode.folder(name: $0, children: materialize(level.folders[$0]!))
            }
            let leaves = level.leaves.keys.sorted(by: NaturalOrder.less).map { level.leaves[$0]! }
            return folders + leaves
        }
        return materialize(root)
    }

    /// Audio tracks in display order: the playback queue for the tree.
    public static func playbackOrder(_ nodes: [WorkTreeNode]) -> [Track] {
        nodes.flatMap { node -> [Track] in
            switch node {
            case .folder(_, let children): playbackOrder(children)
            case .track(let track): [track]
            case .file: []
            }
        }
    }

    /// Folder path to open first: descend while one child folder holds more
    /// than 60% of this level's audio bytes. Bytes capture both "long" (本編
    /// vs short 特典 clips) and "lossless" (WAV ≈ 10× MP3, ≈ 2× FLAC, so a
    /// WAV/FLAC pair at ~67% still descends into WAV); parallel variants
    /// (SEあり/なし, Disc1/Disc2) split ~50/50 and stop the walk.
    public static func autoPath(_ nodes: [WorkTreeNode]) -> [String] {
        var path: [String] = []
        var level = nodes
        while true {
            let total = level.reduce(0) { $0 + $1.audioBytes }
            let best = level.filter { if case .folder = $0 { true } else { false } }
                .max { $0.audioBytes < $1.audioBytes }
            guard let best, best.audioBytes * 10 > total * 6 else { break }
            path.append(best.name)
            level = best.children
        }
        return path
    }
}

/// A folder holding audio directly, as offered by the detail page's track
/// list; `path` is empty for audio at the work's root.
public struct AudioFolder: Sendable, Hashable {
    public let path: [String]
    public let tracks: [Track]
}

extension WorkTree {
    /// Every folder with tracks of its own, in tree order.
    public static func audioFolders(_ nodes: [WorkTreeNode]) -> [AudioFolder] {
        func walk(_ nodes: [WorkTreeNode], _ path: [String]) -> [AudioFolder] {
            let tracks = nodes.compactMap { node -> Track? in
                if case .track(let track) = node { track } else { nil }
            }
            let own = tracks.isEmpty ? [] : [AudioFolder(path: path, tracks: tracks)]
            return own + nodes.flatMap { node -> [AudioFolder] in
                if case .folder(let name, let children) = node { walk(children, path + [name]) } else { [] }
            }
        }
        return walk(nodes, [])
    }

    /// The folder the track list opens at: the first one inside `autoPath`.
    public static func defaultAudioFolder(_ nodes: [WorkTreeNode]) -> AudioFolder? {
        let folders = audioFolders(nodes)
        let preferred = autoPath(nodes)
        return folders.first { $0.path.starts(with: preferred) } ?? folders.first
    }
}

/// A folder row on the files page. A folder holding nothing but folders is
/// skipped over, its children listed as `parent · child`, so `本編/WAV`
/// opens in one tap.
public struct FolderEntry: Sendable {
    public let path: [String]
    public let label: String
    public let node: WorkTreeNode
}

extension WorkTreeNode {
    /// Files below this node by kind (`audio` for tracks, else `fileKind`).
    public var kindCounts: [String: Int] {
        switch self {
        case .folder(_, let children): children.reduce(into: [:]) { $0.merge($1.kindCounts, uniquingKeysWith: +) }
        case .track: ["audio": 1]
        case .file(let file): [file.fileKind: 1]
        }
    }

    var isFolder: Bool {
        if case .folder = self { true } else { false }
    }
}

extension WorkTree {
    /// The nodes inside the folder at `path`.
    public static func level(_ nodes: [WorkTreeNode], at path: [String]) -> [WorkTreeNode] {
        path.reduce(nodes) { level, name in
            level.first { $0.isFolder && $0.name == name }!.children
        }
    }

    public static func folderEntries(_ level: [WorkTreeNode], at path: [String]) -> [FolderEntry] {
        level.filter(\.isFolder).flatMap { node -> [FolderEntry] in
            let children = node.children
            if !children.isEmpty && children.allSatisfy(\.isFolder) {
                return folderEntries(children, at: path + [node.name]).map {
                    FolderEntry(path: $0.path, label: "\(node.name) · \($0.label)", node: $0.node)
                }
            }
            return [FolderEntry(path: path + [node.name], label: node.name, node: node)]
        }
    }

    /// The pages from the root to `path`, one per folder row tapped.
    public static func steps(_ nodes: [WorkTreeNode], to path: [String]) -> [FolderEntry] {
        var steps: [FolderEntry] = []
        var current: [String] = []
        while current != path {
            let entry = folderEntries(level(nodes, at: current), at: current).first { path.starts(with: $0.path) }!
            steps.append(entry)
            current = entry.path
        }
        return steps
    }
}

extension Track {
    /// Folders from the work's root down to this track.
    public var folderPath: [String] {
        relativePath.split(separator: "/").dropLast().map(String.init)
    }
}

/// Natural-order compare: digit runs compare numerically (leading zeros
/// ignored), everything else by UTF-16 code unit, like the Flutter build.
public enum NaturalOrder {
    public static func less(_ a: String, _ b: String) -> Bool { compare(a, b) < 0 }

    public static func compare(_ a: String, _ b: String) -> Int {
        let a = Array(a.utf16), b = Array(b.utf16)
        func isDigit(_ c: UInt16) -> Bool { c >= 0x30 && c <= 0x39 }
        var i = 0, j = 0
        while i < a.count && j < b.count {
            if isDigit(a[i]) && isDigit(b[j]) {
                var ai = i, bj = j
                while ai < a.count && isDigit(a[ai]) { ai += 1 }
                while bj < b.count && isDigit(b[bj]) { bj += 1 }
                var aStart = i, bStart = j
                while aStart < ai - 1 && a[aStart] == 0x30 { aStart += 1 }
                while bStart < bj - 1 && b[bStart] == 0x30 { bStart += 1 }
                let aLen = ai - aStart, bLen = bj - bStart
                if aLen != bLen { return aLen - bLen }
                for k in 0..<aLen where a[aStart + k] != b[bStart + k] {
                    return Int(a[aStart + k]) - Int(b[bStart + k])
                }
                i = ai
                j = bj
            } else {
                if a[i] != b[j] { return Int(a[i]) - Int(b[j]) }
                i += 1
                j += 1
            }
        }
        return (a.count - i) - (b.count - j)
    }
}
