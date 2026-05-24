import Flutter
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
    guard let url = URL(string: urlString) else { throw BookmarkError.invalidUrl }
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
    if started {
      lock.lock()
      activeUrls[url.absoluteString] = url
      lock.unlock()
    }
    return (url.absoluteString, stale)
  }

  private func release(urlString: String) {
    lock.lock()
    let url = activeUrls.removeValue(forKey: urlString)
    lock.unlock()
    url?.stopAccessingSecurityScopedResource()
  }
}
