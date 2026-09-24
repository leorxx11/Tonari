import AVFoundation

/// Where audio is going, shown the way Apple Music labels its AirPlay button.
struct AudioRoute: Equatable {
    /// Nil while playing through the phone itself.
    let name: String?
    let symbol: String

    static var current: AudioRoute {
        guard let output = AVAudioSession.sharedInstance().currentRoute.outputs.first else {
            return AudioRoute(name: nil, symbol: "airplay.audio")
        }
        let name = output.portName
        let lowered = name.lowercased()
        let symbol: String
        switch output.portType {
        case .builtInSpeaker, .builtInReceiver:
            return AudioRoute(name: nil, symbol: "airplay.audio")
        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
            symbol = if lowered.contains("airpods max") { "airpods.max" }
                else if lowered.contains("airpods pro") { "airpods.pro" }
                else if lowered.contains("airpods") { "airpods" }
                else if lowered.contains("beats") { "beats.headphones" }
                else { "headphones" }
        case .headphones, .usbAudio:
            symbol = "headphones"
        case .airPlay:
            symbol = if lowered.contains("homepod mini") { "homepod.mini" }
                else if lowered.contains("homepod") { "homepod" }
                else if lowered.contains("tv") { "appletv" }
                else { "hifispeaker" }
        case .carAudio:
            symbol = "car"
        case .HDMI:
            symbol = "tv"
        default:
            symbol = "hifispeaker"
        }
        return AudioRoute(name: name, symbol: symbol)
    }
}
