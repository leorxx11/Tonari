import AVFoundation
import AVKit
import Flutter
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
    PipPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "PipPlugin")!
    )
    IosSelectableTextPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "IosSelectableTextPlugin")!
    )
  }
}

// MARK: - Native selectable text

private enum IosSelectableTextPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      IosSelectableTextFactory(messenger: registrar.messenger()),
      withId: "tonari/ios_selectable_text"
    )
  }
}

private final class IosSelectableTextFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return IosSelectableTextView(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      messenger: messenger
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class IosSelectableTextView: NSObject, FlutterPlatformView, UITextViewDelegate {
  private let textView: UITextView
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    let args = arguments as! [String: Any]
    let text = args["text"] as! String
    let fontSize = CGFloat(args["fontSize"] as! Double)
    let fontWeight = args["fontWeight"] as! Int
    let color = args["color"] as! Int
    let textAlign = args["textAlign"] as! String
    let textDirection = args["textDirection"] as! String

    textView = UITextView(frame: frame)
    channel = FlutterMethodChannel(
      name: "tonari/ios_selectable_text/\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    textView.backgroundColor = .clear
    textView.isOpaque = false
    textView.isEditable = false
    textView.isSelectable = true
    textView.isScrollEnabled = false
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.textContainer.lineBreakMode = .byWordWrapping
    textView.contentInset = .zero
    textView.adjustsFontForContentSizeCategory = false

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = Self.alignment(textAlign, direction: textDirection)
    paragraph.baseWritingDirection = textDirection == "rtl" ? .rightToLeft : .leftToRight
    paragraph.lineBreakMode = .byWordWrapping
    if let factor = args["lineHeightFactor"] as? Double {
      let lineHeight = fontSize * CGFloat(factor)
      paragraph.minimumLineHeight = lineHeight
      paragraph.maximumLineHeight = lineHeight
    }

    var attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: fontSize, weight: Self.weight(fontWeight)),
      .foregroundColor: Self.color(color),
      .paragraphStyle: paragraph,
    ]
    if let letterSpacing = args["letterSpacing"] as? Double {
      attributes[.kern] = letterSpacing
    }
    textView.attributedText = NSAttributedString(string: text, attributes: attributes)
    textView.delegate = self

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "deactivate":
        self?.deactivate()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView {
    return textView
  }

  func textViewDidChangeSelection(_ textView: UITextView) {
    let range = textView.selectedRange
    let active = range.length > 0
    if !active {
      channel.invokeMethod("selectionChanged", arguments: ["active": false])
      return
    }

    let startPosition = textView.position(
      from: textView.beginningOfDocument,
      offset: range.location
    )!
    let endPosition = textView.position(
      from: textView.beginningOfDocument,
      offset: range.location + range.length
    )!
    let startRect = textView.caretRect(for: startPosition)
    let endRect = textView.caretRect(for: endPosition)
    channel.invokeMethod("selectionChanged", arguments: [
      "active": true,
      "startX": startRect.midX,
      "startY": startRect.midY,
      "endX": endRect.midX,
      "endY": endRect.midY,
    ])
  }

  private func deactivate() {
    textView.selectedRange = NSRange(location: 0, length: 0)
    textView.resignFirstResponder()
  }

  private static func alignment(_ value: String, direction: String) -> NSTextAlignment {
    switch value {
    case "center": return .center
    case "right": return .right
    case "justify": return .justified
    case "end": return direction == "rtl" ? .left : .right
    default: return direction == "rtl" ? .right : .left
    }
  }

  private static func weight(_ value: Int) -> UIFont.Weight {
    switch value {
    case ...150: return .ultraLight
    case ...250: return .thin
    case ...350: return .light
    case ...450: return .regular
    case ...550: return .medium
    case ...650: return .semibold
    case ...750: return .bold
    case ...850: return .heavy
    default: return .black
    }
  }

  private static func color(_ value: Int) -> UIColor {
    return UIColor(
      red: CGFloat((value >> 16) & 0xff) / 255,
      green: CGFloat((value >> 8) & 0xff) / 255,
      blue: CGFloat(value & 0xff) / 255,
      alpha: CGFloat((value >> 24) & 0xff) / 255
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

// MARK: - Picture-in-Picture subtitle window plugin

/// Bridges Dart's `tonari/pip` method channel to a system-level PiP window
/// that renders the current subtitle cue. Implementation strategy:
///   - Create an `AVSampleBufferDisplayLayer` and attach it to a 1×1 invisible
///     host view in the key window (PiP requires the layer to be on-screen).
///   - Wrap it in `AVPictureInPictureController(contentSource:)` (iOS 15+).
///   - Whenever Dart calls `update(text:)`, paint `text` onto a CVPixelBuffer,
///     wrap it in a CMSampleBuffer, and enqueue it on the display layer.
///   - `start()` / `stop()` toggle PiP itself. The user gesture comes from
///     the captions-cycle button on the player page.
private final class PipPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "tonari/pip",
      binaryMessenger: registrar.messenger()
    )
    let instance = PipPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private let controller = PipSubtitleController()

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(AVPictureInPictureController.isPictureInPictureSupported())
    case "start":
      controller.start()
      result(nil)
    case "stop":
      controller.stop()
      result(nil)
    case "update":
      let args = call.arguments as? [String: Any]
      let text = args?["text"] as? String ?? ""
      controller.update(text: text)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private final class PipSubtitleController: NSObject {
  private let displayLayer = AVSampleBufferDisplayLayer()
  private var pipController: AVPictureInPictureController?
  private var hostView: UIView?
  private var lastRenderedText: String = ""
  private var hasEnqueuedAtLeastOneFrame = false
  private var pendingStart = false
  private var pipPossibleObservation: NSKeyValueObservation?

  // 7:1 wide-strip canvas — PiP scales the window to this aspect ratio.
  // Long-and-thin so it sits on screen like a system caption bar.
  private static let canvasWidth = 700
  private static let canvasHeight = 100

  override init() {
    super.init()
    DispatchQueue.main.async { [weak self] in
      self?.setupHostAndPip()
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  private func setupHostAndPip() {
    guard AVPictureInPictureController.isPictureInPictureSupported() else {
      return
    }
    guard let window = Self.keyWindow() else {
      // Window not ready yet — retry shortly. happens during cold start.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        self?.setupHostAndPip()
      }
      return
    }

    let host = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    host.isUserInteractionEnabled = false
    host.isHidden = false
    host.alpha = 0.01
    displayLayer.frame = host.bounds
    displayLayer.videoGravity = .resizeAspect
    host.layer.addSublayer(displayLayer)
    window.addSubview(host)
    hostView = host

    if #available(iOS 15.0, *) {
      let contentSource = AVPictureInPictureController.ContentSource(
        sampleBufferDisplayLayer: displayLayer,
        playbackDelegate: self
      )
      let pip = AVPictureInPictureController(contentSource: contentSource)
      pip.delegate = self
      pipController = pip
      if pendingStart {
        pendingStart = false
        start()
      }
    }
  }

  private static func keyWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  func start() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard let pip = self.pipController else {
        // Controller is still spinning up (cold start). Replay once ready.
        self.pendingStart = true
        return
      }
      // PiP refuses to start until at least one frame has been enqueued;
      // an empty cue renders as a blank black frame, which still counts.
      self.renderText(self.lastRenderedText)
      self.startWhenPossible(pip)
    }
  }

  /// Starts PiP as soon as AVKit reports it's possible (i.e. the first frame
  /// has been ingested), instead of betting on a fixed delay. A hard timeout
  /// forces an attempt so a stuck `isPictureInPicturePossible` can't wedge us.
  private func startWhenPossible(_ pip: AVPictureInPictureController) {
    if pip.isPictureInPicturePossible {
      pip.startPictureInPicture()
      return
    }
    pipPossibleObservation?.invalidate()
    pipPossibleObservation = pip.observe(
      \.isPictureInPicturePossible,
      options: [.new]
    ) { [weak self] pip, _ in
      guard pip.isPictureInPicturePossible else { return }
      pip.startPictureInPicture()
      self?.pipPossibleObservation?.invalidate()
      self?.pipPossibleObservation = nil
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      guard let self = self, self.pipPossibleObservation != nil else { return }
      self.pipPossibleObservation?.invalidate()
      self.pipPossibleObservation = nil
      pip.startPictureInPicture()
    }
  }

  func stop() {
    DispatchQueue.main.async { [weak self] in
      self?.pipController?.stopPictureInPicture()
    }
  }

  func update(text: String) {
    // Empty means "no cue right now" (e.g. before a track's first line) —
    // render a blank frame, not a loading placeholder: the subtitle itself
    // loads from the local DB in milliseconds.
    if text == lastRenderedText && hasEnqueuedAtLeastOneFrame { return }
    lastRenderedText = text
    DispatchQueue.main.async { [weak self] in
      self?.renderText(text)
    }
  }

  @objc private func handleDidBecomeActive() {
    // Returning from background often leaves the display layer in a failed
    // state where enqueue is silently dropped. Replay the current cue;
    // enqueuePixelBuffer flushes first when the layer has failed.
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.hasEnqueuedAtLeastOneFrame else { return }
      self.renderText(self.lastRenderedText)
    }
  }

  /// Paints [text] (white, centered) on a black background and pushes the
  /// pixel buffer to the display layer.
  private func renderText(_ text: String) {
    let width = Self.canvasWidth
    let height = Self.canvasHeight

    var pixelBuffer: CVPixelBuffer?
    let attrs: [CFString: Any] = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      // Required by AVSampleBufferDisplayLayer when rendering through PiP —
      // without it the layer silently drops frames at the IOSurface boundary.
      kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
    ]
    CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      attrs as CFDictionary,
      &pixelBuffer
    )
    guard let buffer = pixelBuffer else { return }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    let base = CVPixelBufferGetBaseAddress(buffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    // CVPixelBuffer 32BGRA stores BGRA in memory; the matching CGContext
    // config is "byte order 32 little + alpha skip-first" (ARGB logical →
    // BGRA on disk). premultipliedFirst was the wrong key — 32BGRA isn't
    // premultiplied.
    let bitmapInfo =
      CGImageAlphaInfo.noneSkipFirst.rawValue
      | CGBitmapInfo.byteOrder32Little.rawValue

    guard
      let context = CGContext(
        data: base,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
      )
    else { return }

    // Solid black background.
    context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1.0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Draw the text using UIKit's NSAttributedString in a flipped context
    // (Core Graphics origin is bottom-left, UIKit text expects top-left).
    UIGraphicsPushContext(context)
    defer { UIGraphicsPopContext() }
    context.saveGState()
    defer { context.restoreGState() }
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byTruncatingTail
    let attrString = NSAttributedString(
      string: text,
      attributes: [
        .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
        .foregroundColor: UIColor.white,
        .paragraphStyle: paragraph,
      ]
    )

    let inset: CGFloat = 16
    let drawWidth = CGFloat(width) - inset * 2
    let textBounds = attrString.boundingRect(
      with: CGSize(width: drawWidth, height: CGFloat(height)),
      options: [.usesLineFragmentOrigin],
      context: nil
    )
    let drawRect = CGRect(
      x: inset,
      y: max(inset, (CGFloat(height) - textBounds.height) / 2),
      width: drawWidth,
      height: textBounds.height
    )
    attrString.draw(with: drawRect, options: [.usesLineFragmentOrigin], context: nil)

    enqueuePixelBuffer(buffer)
    hasEnqueuedAtLeastOneFrame = true
  }

  private func enqueuePixelBuffer(_ pixelBuffer: CVPixelBuffer) {
    var formatDesc: CMFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixelBuffer,
      formatDescriptionOut: &formatDesc
    )
    guard let format = formatDesc else { return }

    let presentation = CMClockGetTime(CMClockGetHostTimeClock())
    var timing = CMSampleTimingInfo(
      duration: .invalid,
      presentationTimeStamp: presentation,
      decodeTimeStamp: .invalid
    )

    var sampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixelBuffer,
      formatDescription: format,
      sampleTiming: &timing,
      sampleBufferOut: &sampleBuffer
    )
    guard let sb = sampleBuffer else { return }
    if let attachments = CMSampleBufferGetSampleAttachmentsArray(
      sb,
      createIfNecessary: true
    ) {
      let attachment = unsafeBitCast(
        CFArrayGetValueAtIndex(attachments, 0),
        to: CFMutableDictionary.self
      )
      CFDictionarySetValue(
        attachment,
        Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
        Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
      )
    }
    if displayLayer.status == .failed {
      displayLayer.flush()
    }
    displayLayer.enqueue(sb)
  }
}

// MARK: - PiP delegates

@available(iOS 15.0, *)
extension PipSubtitleController: AVPictureInPictureSampleBufferPlaybackDelegate {
  func pictureInPictureController(
    _ pip: AVPictureInPictureController,
    setPlaying playing: Bool
  ) {
    // Playback is owned by just_audio on the Dart side; nothing to toggle
    // here. The PiP overlay's play/pause control becomes a no-op.
  }

  func pictureInPictureControllerTimeRangeForPlayback(
    _ pip: AVPictureInPictureController
  ) -> CMTimeRange {
    // Effectively-live content — there's nothing to scrub through.
    return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
  }

  func pictureInPictureControllerIsPlaybackPaused(
    _ pip: AVPictureInPictureController
  ) -> Bool {
    return false
  }

  func pictureInPictureController(
    _ pip: AVPictureInPictureController,
    didTransitionToRenderSize newRenderSize: CMVideoDimensions
  ) {}

  func pictureInPictureController(
    _ pip: AVPictureInPictureController,
    skipByInterval skipInterval: CMTime,
    completion completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}

@available(iOS 15.0, *)
extension PipSubtitleController: AVPictureInPictureControllerDelegate {
  func pictureInPictureControllerWillStartPictureInPicture(
    _ pip: AVPictureInPictureController
  ) {}
  func pictureInPictureControllerDidStartPictureInPicture(
    _ pip: AVPictureInPictureController
  ) {}
  func pictureInPictureControllerWillStopPictureInPicture(
    _ pip: AVPictureInPictureController
  ) {}
  func pictureInPictureControllerDidStopPictureInPicture(
    _ pip: AVPictureInPictureController
  ) {}
}
