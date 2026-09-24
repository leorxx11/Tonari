import Foundation

extension Subtitle {
    /// The line to show at a playback position: the last one that has
    /// started, so a pause between lines keeps the previous one on screen
    /// instead of flickering. Nil before the first line.
    public func lineIndex(at positionMs: Int) -> Int? {
        let target = positionMs - timeOffsetMs
        var low = 0
        var high = originalLinesJson.count - 1
        var found: Int?
        while low <= high {
            let mid = (low + high) / 2
            if originalLinesJson[mid].startMs <= target {
                found = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return found
    }

    /// Playback position at which a line appears, honouring the offset.
    public func positionMs(ofLine index: Int) -> Int {
        max(0, originalLinesJson[index].startMs + timeOffsetMs)
    }
}
