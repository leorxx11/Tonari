import Foundation

public enum RJID {
    /// First `RJ` + 6–8 digits in `text`, uppercased (e.g. `RJ01560714`).
    public static func extract(_ text: String) -> String? {
        text.firstMatch(of: /(?i)RJ(\d{6,8})/).map { "RJ\($0.1)" }
    }
}

public enum FileKind: String, Sendable {
    case audio, video, image, subtitle, text, other

    public init(fileName: String) {
        switch FileKind.ext(fileName) {
        case "wav", "mp3", "flac", "m4a", "ogg", "opus", "aac": self = .audio
        case "mp4", "mkv", "mov", "m4v", "webm", "ts": self = .video
        case "jpg", "jpeg", "png", "webp", "bmp", "gif": self = .image
        case "srt", "lrc", "vtt", "ass", "ssa": self = .subtitle
        case "txt", "md", "html", "htm": self = .text
        default: self = .other
        }
    }

    /// Lowercased extension without the dot; empty when there is none.
    public static func ext(_ fileName: String) -> String {
        guard let dot = fileName.lastIndex(of: ".") else { return "" }
        return fileName[fileName.index(after: dot)...].lowercased()
    }
}

public struct ScannedFile: Sendable, Equatable {
    public let path: String
    /// Relative to the work's root folder, `/`-separated.
    public let relativePath: String
    public let fileName: String
    public let sizeBytes: Int
    public let kind: FileKind

    public var parentDirName: String {
        (path as NSString).deletingLastPathComponent.split(separator: "/").last.map(String.init) ?? ""
    }
}

public struct ScannedWork: Sendable {
    public let productId: String
    public let rootPath: String
    public let files: [ScannedFile]
    /// A directory listing failed midway, so the file set can't be trusted:
    /// import must neither overwrite an existing snapshot nor create a shell.
    public let incomplete: Bool

    public func files(_ kind: FileKind) -> [ScannedFile] { files.filter { $0.kind == kind } }
}

public struct ScanResult: Sendable {
    public let rootPath: String
    public let works: [ScannedWork]
    /// Top-level folders with no RJ id in their name or their children's.
    public let unrecognizedDirs: [String]
    public let errors: [String]
}

/// Finds RJ works under a folder: the folder itself, its children, or its
/// grandchildren (e.g. 合集 → 系列 → RJxxx), each scanned recursively.
public enum FolderScanner {
    /// `only` limits building to one work, for single-work rescans.
    public static func scan(_ root: URL, only productId: String? = nil) -> ScanResult {
        let fm = FileManager.default
        var works: [ScannedWork] = []
        var unrecognized: [String] = []
        var errors: [String] = []

        func add(_ dir: URL, _ id: String) {
            if productId == nil || productId == id { works.append(buildWork(dir, id, &errors)) }
        }
        func subdirectories(_ dir: URL) throws -> [URL] {
            try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])
                .filter { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory! }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        if let id = RJID.extract(root.lastPathComponent) {
            add(root, id)
        } else {
            do {
                for child in try subdirectories(root) {
                    if let id = RJID.extract(child.lastPathComponent) {
                        add(child, id)
                        continue
                    }
                    var found = false
                    do {
                        for grandchild in try subdirectories(child) {
                            if let id = RJID.extract(grandchild.lastPathComponent) {
                                add(grandchild, id)
                                found = true
                            }
                        }
                    } catch {
                        errors.append("\(child.path): \(error.localizedDescription)")
                    }
                    if !found { unrecognized.append(child.path) }
                }
            } catch {
                errors.append("\(root.path): \(error.localizedDescription)")
            }
        }
        return ScanResult(rootPath: root.path, works: works, unrecognizedDirs: unrecognized, errors: errors)
    }

    private static func buildWork(_ dir: URL, _ productId: String, _ errors: inout [String]) -> ScannedWork {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let rootPath = dir.resolvingSymlinksInPath().path + "/"
        final class Failures {
            var messages: [String] = []
        }
        let listing = Failures()
        var files: [ScannedFile] = []
        var failed = false
        let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: keys) { url, error in
            listing.messages.append("\(url.path): \(error.localizedDescription)")
            return true
        }!
        for case let url as URL in enumerator {
            do {
                let values = try url.resourceValues(forKeys: Set(keys))
                guard values.isRegularFile! else { continue }
                let path = url.resolvingSymlinksInPath().path
                let name = url.lastPathComponent
                files.append(ScannedFile(
                    path: path,
                    relativePath: String(path.dropFirst(rootPath.count)),
                    fileName: name,
                    sizeBytes: values.fileSize!,
                    kind: FileKind(fileName: name)
                ))
            } catch {
                errors.append("\(url.path): \(error.localizedDescription)")
                failed = true
            }
        }
        errors += listing.messages
        return ScannedWork(
            productId: productId, rootPath: dir.resolvingSymlinksInPath().path, files: files,
            incomplete: failed || !listing.messages.isEmpty
        )
    }

    /// 'main' / 'free' from 本編 / フリートーク-style keywords in the folder or
    /// file name; a suggestion only.
    public static func categoryHint(parentDir: String, fileName: String) -> String? {
        for s in [parentDir.lowercased(), fileName.lowercased()] {
            if s.contains("本編") || s.contains("本编") || s.contains("main") { return "main" }
            if s.contains("フリートーク") || s.contains("free") || s.contains("talk") { return "free" }
        }
        return nil
    }
}
