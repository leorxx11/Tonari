import Foundation
import TonariCore

/// Player settings under the Flutter build's preference keys.
@Observable
final class PlayerPrefs {
    static let seekStepPresets = [5, 10, 15, 30, 60]
    private static let seekStepKey = "player.seekStepSeconds"
    private static let sleepFinishKey = "player.sleepFinishCurrentTrack"

    var seekStep: Int {
        didSet { UserDefaults.standard.set(seekStep, forKey: Self.seekStepKey) }
    }
    var mode: PlaybackMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: PlaybackMode.preferenceKey) }
    }
    /// When the sleep countdown ends mid-track, let the track finish.
    var sleepFinishCurrentTrack: Bool {
        didSet { UserDefaults.standard.set(sleepFinishCurrentTrack, forKey: Self.sleepFinishKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        seekStep = defaults.object(forKey: Self.seekStepKey) as? Int ?? 15
        mode = defaults.string(forKey: PlaybackMode.preferenceKey).flatMap(PlaybackMode.init) ?? .sequence
        sleepFinishCurrentTrack = defaults.bool(forKey: Self.sleepFinishKey)
    }
}
