import Foundation

/// What happens when a track finishes on its own. Stored under the Flutter
/// build's key with its case names.
public enum PlaybackMode: String, CaseIterable, Sendable {
    case sequence, loopAll, loopOne, shuffle

    public static let preferenceKey = "player.playbackMode"

    public var label: String {
        switch self {
        case .sequence: "顺序播放"
        case .loopAll: "列表循环"
        case .loopOne: "单曲循环"
        case .shuffle: "随机播放"
        }
    }

    public var next: PlaybackMode {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    /// The queue index to play once `current` completes, or nil to stop.
    public func indexAfterCompletion(
        current: Int, count: Int, using generator: inout some RandomNumberGenerator
    ) -> Int? {
        switch self {
        case .sequence:
            return current + 1 < count ? current + 1 : nil
        case .loopAll:
            return (current + 1) % count
        case .loopOne:
            return current
        case .shuffle:
            guard count > 1 else { return current }
            let pick = Int.random(in: 0..<count, using: &generator)
            return pick == current ? (pick + 1) % count : pick
        }
    }
}
