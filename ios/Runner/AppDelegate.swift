import Flutter
import AVFoundation
import MediaPlayer
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    BookmarkPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "BookmarkPlugin")!
    )
    NowPlayingPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "NowPlayingPlugin")!
    )
  }
}

// MARK: - Security-scoped bookmark plugin

private enum BookmarkError: LocalizedError {
  case invalidUrl
  case invalidBookmark

  var errorDescription: String? {
    switch self {
    case .invalidUrl: return "Invalid URL string"
    case .invalidBookmark: return "Bookmark base64 could not be decoded"
    }
  }
}

private final class BookmarkPlugin: NSObject, FlutterPlugin {
  private var activeUrls: [String: URL] = [:]
  private let lock = NSLock()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "tonari/folder_bookmark",
      binaryMessenger: registrar.messenger()
    )
    let instance = BookmarkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "create":
        let args = call.arguments as! [String: Any]
        let url = args["url"] as! String
        result(try create(urlString: url))
      case "resolve":
        let args = call.arguments as! [String: Any]
        let bookmark = args["bookmark"] as! String
        let resolved = try resolve(bookmarkBase64: bookmark)
        result(["url": resolved.url, "isStale": resolved.isStale])
      case "release":
        let args = call.arguments as! [String: Any]
        let url = args["url"] as! String
        release(urlString: url)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(
        code: "BOOKMARK_ERROR",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  private func create(urlString: String) throws -> String {
    let url = try fileUrl(from: urlString)
    let started = url.startAccessingSecurityScopedResource()
    defer { if started { url.stopAccessingSecurityScopedResource() } }
    let data = try url.bookmarkData(
      options: [],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    return data.base64EncodedString()
  }

  private func resolve(bookmarkBase64: String) throws -> (url: String, isStale: Bool) {
    guard let data = Data(base64Encoded: bookmarkBase64) else {
      throw BookmarkError.invalidBookmark
    }
    var stale = false
    let url = try URL(
      resolvingBookmarkData: data,
      options: [],
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    )
    let started = url.startAccessingSecurityScopedResource()
    let path = decodedPath(url.path)
    if started {
      lock.lock()
      activeUrls[path] = url
      lock.unlock()
    }
    return (path, stale)
  }

  private func release(urlString: String) {
    lock.lock()
    let url = activeUrls.removeValue(forKey: urlString)
    lock.unlock()
    url?.stopAccessingSecurityScopedResource()
  }

  private func fileUrl(from string: String) throws -> URL {
    if string.hasPrefix("file://") {
      guard let url = URL(string: string) else { throw BookmarkError.invalidUrl }
      return url
    }
    return URL(fileURLWithPath: decodedPath(string))
  }

  private func decodedPath(_ path: String) -> String {
    return path.removingPercentEncoding ?? path
  }
}

// MARK: - Now playing plugin

private final class NowPlayingPlugin: NSObject, FlutterPlugin {
  private let center = MPNowPlayingInfoCenter.default()
  private let commandCenter = MPRemoteCommandCenter.shared()
  private var channel: FlutterMethodChannel!
  private var commandsRegistered = false
  private var artworkPath: String?
  private var artworkCache: MPMediaItemArtwork?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "tonari/now_playing",
      binaryMessenger: registrar.messenger()
    )
    let instance = NowPlayingPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "update":
      update(call.arguments as! [String: Any])
      result(nil)
    case "clear":
      clear()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func update(_ args: [String: Any]) {
    activateAudioSession()
    registerCommands()

    let title = args["title"] as! String
    let album = args["album"] as! String
    let artist = args["artist"] as! String
    let artworkPath = args["artworkPath"] as? String
    let positionMs = args["positionMs"] as! Int
    let durationMs = args["durationMs"] as! Int
    let playing = args["playing"] as! Bool
    let speed = args["speed"] as! Double
    let hasPrevious = args["hasPrevious"] as! Bool
    let hasNext = args["hasNext"] as! Bool

    commandCenter.playCommand.isEnabled = true
    commandCenter.pauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.isEnabled = false
    commandCenter.previousTrackCommand.isEnabled = hasPrevious
    commandCenter.nextTrackCommand.isEnabled = hasNext
    if #available(iOS 9.1, *) {
      commandCenter.changePlaybackPositionCommand.isEnabled = durationMs > 0
    }

    var info: [String: Any] = [
      MPMediaItemPropertyTitle: title,
      MPMediaItemPropertyAlbumTitle: album,
      MPMediaItemPropertyArtist: artist,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(positionMs) / 1000.0,
      MPNowPlayingInfoPropertyPlaybackRate: playing ? speed : 0.0,
      MPNowPlayingInfoPropertyDefaultPlaybackRate: speed,
    ]
    if durationMs > 0 {
      info[MPMediaItemPropertyPlaybackDuration] = Double(durationMs) / 1000.0
    }
    if #available(iOS 10.0, *) {
      info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
    }
    if let artwork = resolveArtwork(path: artworkPath) {
      info[MPMediaItemPropertyArtwork] = artwork
    }

    center.nowPlayingInfo = info
    if #available(iOS 13.0, *) {
      center.playbackState = playing ? .playing : .paused
    }
    UIApplication.shared.beginReceivingRemoteControlEvents()
  }

  private func resolveArtwork(path: String?) -> MPMediaItemArtwork? {
    guard let path = path, !path.isEmpty else {
      artworkPath = nil
      artworkCache = nil
      return nil
    }
    if path == artworkPath, let cached = artworkCache {
      return cached
    }
    guard let image = UIImage(contentsOfFile: path) else {
      artworkPath = nil
      artworkCache = nil
      return nil
    }
    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    artworkPath = path
    artworkCache = artwork
    return artwork
  }

  private func activateAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .spokenAudio)
    try? session.setActive(true)
  }

  private func clear() {
    center.nowPlayingInfo = nil
    if #available(iOS 13.0, *) {
      center.playbackState = .stopped
    }
    artworkPath = nil
    artworkCache = nil
    commandCenter.playCommand.isEnabled = false
    commandCenter.pauseCommand.isEnabled = false
    commandCenter.togglePlayPauseCommand.isEnabled = false
    commandCenter.previousTrackCommand.isEnabled = false
    commandCenter.nextTrackCommand.isEnabled = false
    if #available(iOS 9.1, *) {
      commandCenter.changePlaybackPositionCommand.isEnabled = false
    }
  }

  private func registerCommands() {
    if commandsRegistered { return }
    commandCenter.playCommand.addTarget(self, action: #selector(play(_:)))
    commandCenter.pauseCommand.addTarget(self, action: #selector(pause(_:)))
    commandCenter.previousTrackCommand.addTarget(self, action: #selector(previous(_:)))
    commandCenter.nextTrackCommand.addTarget(self, action: #selector(next(_:)))
    if #available(iOS 9.1, *) {
      commandCenter.changePlaybackPositionCommand.addTarget(
        self,
        action: #selector(changePlaybackPosition(_:))
      )
    }
    commandsRegistered = true
  }

  @objc private func play(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    channel.invokeMethod("play", arguments: nil)
    return .success
  }

  @objc private func pause(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    channel.invokeMethod("pause", arguments: nil)
    return .success
  }

  @objc private func previous(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    channel.invokeMethod("previous", arguments: nil)
    return .success
  }

  @objc private func next(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    channel.invokeMethod("next", arguments: nil)
    return .success
  }

  @available(iOS 9.1, *)
  @objc private func changePlaybackPosition(
    _ event: MPChangePlaybackPositionCommandEvent
  ) -> MPRemoteCommandHandlerStatus {
    channel.invokeMethod(
      "seek",
      arguments: ["positionMs": Int(event.positionTime * 1000)]
    )
    return .success
  }
}
