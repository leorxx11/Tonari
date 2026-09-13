import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let privacyBlur: UIVisualEffectView = {
    let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.accessibilityElementsHidden = true
    return view
  }()

  override func sceneWillResignActive(_ scene: UIScene) {
    // SharedPreferences stores this key in the same app's standard UserDefaults.
    let enabled = UserDefaults.standard.object(forKey: "flutter.privacy.blurOnBackground")
      as? Bool ?? true
    if enabled {
      let window = window!
      privacyBlur.frame = window.bounds
      // Cover the window before Flutter suspends rendering and iOS snapshots it.
      window.addSubview(privacyBlur)
    }
    super.sceneWillResignActive(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyBlur.removeFromSuperview()
  }
}
