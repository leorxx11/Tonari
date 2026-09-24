import Foundation
import mdk

public final class MDKPlayer: @unchecked Sendable {
    public enum State: Sendable {
        case stopped, playing, paused
    }

    public struct MediaStatus: OptionSet, Sendable {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }

        public static let loading = MediaStatus(rawValue: MDK_MediaStatus_Loading.rawValue)
        public static let loaded = MediaStatus(rawValue: MDK_MediaStatus_Loaded.rawValue)
        public static let prepared = MediaStatus(rawValue: MDK_MediaStatus_Prepared.rawValue)
        public static let stalled = MediaStatus(rawValue: MDK_MediaStatus_Stalled.rawValue)
        public static let buffering = MediaStatus(rawValue: MDK_MediaStatus_Buffering.rawValue)
        public static let buffered = MediaStatus(rawValue: MDK_MediaStatus_Buffered.rawValue)
        public static let end = MediaStatus(rawValue: MDK_MediaStatus_End.rawValue)
        public static let seeking = MediaStatus(rawValue: MDK_MediaStatus_Seeking.rawValue)
        public static let invalid = MediaStatus(rawValue: MDK_MediaStatus_Invalid.rawValue)

        public var names: String {
            let all: [(MediaStatus, String)] = [
                (.loading, "loading"), (.loaded, "loaded"), (.prepared, "prepared"), (.stalled, "stalled"),
                (.buffering, "buffering"), (.buffered, "buffered"), (.end, "end"), (.seeking, "seeking"),
                (.invalid, "invalid"),
            ]
            let names = all.filter { contains($0.0) }.map(\.1)
            return names.isEmpty ? "none" : names.joined(separator: "|")
        }
    }

    public struct Event: Sendable {
        public let error: Int64
        public let category: String
        public let detail: String
    }

    public struct VideoInfo: Sendable {
        public let codec: String
        public let pixelFormat: String
        public let width: Int
        public let height: Int
        public let frameRate: Float
    }

    private var api: UnsafePointer<mdkPlayerAPI>?
    private var player: OpaquePointer? { api!.pointee.object }

    private var stateHandler: (@Sendable (State) -> Void)?
    private var statusHandler: (@Sendable (MediaStatus) -> Void)?
    private var eventHandler: (@Sendable (Event) -> Void)?

    public init() {
        api = mdkPlayerAPI_new()
    }

    deinit {
        api!.pointee.setState(player, MDK_State_Stopped)
        mdkPlayerAPI_delete(&api)
    }

    private var unretainedSelf: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }

    private static func from(_ opaque: UnsafeRawPointer?) -> MDKPlayer {
        Unmanaged<MDKPlayer>.fromOpaque(opaque!).takeUnretainedValue()
    }

    // MARK: Configuration

    public func setProperty(_ key: String, _ value: String) {
        api!.pointee.setProperty(player, key, value)
    }

    public func property(_ key: String) -> String? {
        api!.pointee.getProperty(player, key).map { String(cString: $0) }
    }

    public func setVideoDecoders(_ names: [String]) {
        var cNames: [UnsafeMutablePointer<CChar>?] = names.map { strdup($0) } + [nil]
        defer { cNames.forEach { free($0) } }
        cNames.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) {
                api!.pointee.setDecoders(player, MDK_MediaType_Video, $0)
            }
        }
    }

    /// FFmpeg only honours a caller User-Agent that follows a line break, so
    /// callers must not put User-Agent first.
    public func setHTTPHeaders(_ headers: [(name: String, value: String)]) {
        setProperty("avio.headers", headers.map { "\($0.name): \($0.value)\r\n" }.joined())
    }

    // MARK: Callbacks

    public func onStateChanged(_ handler: @escaping @Sendable (State) -> Void) {
        stateHandler = handler
        let callback = mdkStateChangedCallback(
            cb: { state, opaque in
                let value: State = switch state {
                case MDK_State_Playing: .playing
                case MDK_State_Paused: .paused
                default: .stopped
                }
                MDKPlayer.from(opaque).stateHandler?(value)
            },
            opaque: unretainedSelf
        )
        api!.pointee.onStateChanged(player, callback)
    }

    public func onMediaStatus(_ handler: @escaping @Sendable (MediaStatus) -> Void) {
        statusHandler = handler
        let callback = mdkMediaStatusCallback(
            cb: { _, newValue, opaque in
                MDKPlayer.from(opaque).statusHandler?(MediaStatus(rawValue: newValue.rawValue))
                return true
            },
            opaque: unretainedSelf
        )
        api!.pointee.onMediaStatus(player, callback, nil)
    }

    public func onEvent(_ handler: @escaping @Sendable (Event) -> Void) {
        eventHandler = handler
        let callback = mdkMediaEventCallback(
            cb: { event, opaque in
                let e = event!.pointee
                MDKPlayer.from(opaque).eventHandler?(Event(
                    error: e.error,
                    category: e.category.map { String(cString: $0) } ?? "",
                    detail: e.detail.map { String(cString: $0) } ?? ""
                ))
                return false
            },
            opaque: unretainedSelf
        )
        api!.pointee.onEvent(player, callback, nil)
    }

    // MARK: Playback

    /// Replaces the current media and resolves once it is loaded and paused,
    /// ready for `state = .playing`; false when it cannot be opened.
    /// mdk requires the previous media to be fully stopped first, and its
    /// prepare callback fires on load, before the player itself switches to
    /// paused — a play request sent earlier is overwritten by that switch.
    /// The callback's position is not a reliable failure signal (a 403 still
    /// reports 0), so success is read from the media status instead.
    public func open(_ url: String, from position: Int64 = 0) async -> Bool {
        state = .stopped
        await waitFor(.stopped)
        api!.pointee.setMedia(player, url)
        await prepare(from: position)
        guard mediaStatus.contains(.loaded) else { return false }
        await waitFor(.paused)
        return true
    }

    private func prepare(from position: Int64) async {
        await withCheckedContinuation { continuation in
            final class Box {
                let continuation: CheckedContinuation<Void, Never>
                init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }
            }
            let box = Unmanaged.passRetained(Box(continuation)).toOpaque()
            let callback = mdkPrepareCallback(
                cb: { _, _, opaque in
                    Unmanaged<Box>.fromOpaque(opaque!).takeRetainedValue().continuation.resume()
                    return true
                },
                opaque: box
            )
            api!.pointee.prepare(player, position, callback, MDK_SeekFlag_Default)
        }
    }

    public var mediaStatus: MediaStatus {
        MediaStatus(rawValue: api!.pointee.mediaStatus(player).rawValue)
    }

    private func waitFor(_ target: State) async {
        let value = Self.mdkState(target)
        await Task.detached { [self] in
            _ = api!.pointee.waitFor(player, value, -1)
        }.value
    }

    private static func mdkState(_ state: State) -> MDK_State {
        switch state {
        case .playing: MDK_State_Playing
        case .paused: MDK_State_Paused
        case .stopped: MDK_State_Stopped
        }
    }

    public var state: State {
        get {
            switch api!.pointee.state(player) {
            case MDK_State_Playing: .playing
            case MDK_State_Paused: .paused
            default: .stopped
            }
        }
        set { api!.pointee.setState(player, Self.mdkState(newValue)) }
    }

    public var positionMs: Int64 { api!.pointee.position(player) }

    public var durationMs: Int64 { api!.pointee.mediaInfo(player)!.pointee.duration }

    public var bufferedMs: Int64 { api!.pointee.buffered(player, nil) }

    public var playbackRate: Float {
        get { api!.pointee.playbackRate(player) }
        set { api!.pointee.setPlaybackRate(player, newValue) }
    }

    public func seek(toMs position: Int64) {
        _ = api!.pointee.seekWithFlags(player, position, MDK_SeekFlag_FromStart, mdkSeekCallback())
    }

    public var videoInfo: VideoInfo? {
        let info = api!.pointee.mediaInfo(player)!.pointee
        guard info.nb_video > 0 else { return nil }
        var params = mdkVideoCodecParameters()
        MDK_VideoStreamCodecParameters(info.video, &params)
        return VideoInfo(
            codec: String(cString: params.codec),
            pixelFormat: params.format_name.map { String(cString: $0) } ?? "",
            width: Int(params.width),
            height: Int(params.height),
            frameRate: params.frame_rate
        )
    }

    // MARK: Rendering

    /// Renders into `surface` (a UIView or CAMetalLayer) on mdk's own render
    /// thread. Call again with the new size whenever the view resizes.
    public func attach(surface: AnyObject, width: Int32, height: Int32) {
        let pointer = Unmanaged.passUnretained(surface).toOpaque()
        var renderAPI = mdkMetalRenderAPI()
        renderAPI.type = MDK_RenderAPI_Metal
        withUnsafePointer(to: &renderAPI) {
            api!.pointee.setRenderAPI(player, OpaquePointer($0), pointer)
        }
        api!.pointee.updateNativeSurface(player, pointer, width, height, MDK_SurfaceType_Auto)
    }
}
