import Foundation

/// How a remote folder's entries are ordered. Folders always come first;
/// ties, and folders when sorting by size, fall back to the name.
public enum RemoteSort: String, CaseIterable, Sendable {
    case name, modifiedAt, size

    public static let preferenceKey = "browse.sort"
    public static let ascendingKey = "browse.sortAscending"

    public var label: String {
        switch self {
        case .name: "名称"
        case .modifiedAt: "修改时间"
        case .size: "大小"
        }
    }

    /// The direction picked when switching to this field: A to Z, newest
    /// first, largest first.
    public var defaultAscending: Bool { self == .name }

    public func sorted(_ entries: [RemoteEntry], ascending: Bool) -> [RemoteEntry] {
        entries.sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            let (x, y) = (key(a), key(b))
            if x != y { return ascending ? x < y : x > y }
            let (m, n) = (a.name.lowercased(), b.name.lowercased())
            return ascending || self != .name ? m < n : m > n
        }
    }

    private func key(_ entry: RemoteEntry) -> Double {
        switch self {
        case .name: 0
        case .modifiedAt: entry.modifiedAt?.timeIntervalSince1970 ?? 0
        case .size: Double(entry.size ?? 0)
        }
    }
}
