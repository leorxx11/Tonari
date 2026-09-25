import SwiftUI
import UIKit

/// Blurs the app whenever it stops being active, so the app switcher's
/// snapshot shows nothing. A window of its own sits above the full-screen
/// players, which a view in the main window can't cover.
enum PrivacyShield {
    static let preferenceKey = "privacy.blurOnBackground"
    private static var window: UIWindow?

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: preferenceKey) as? Bool ?? true
    }

    static func update(_ phase: ScenePhase) {
        guard phase != .active else {
            window?.isHidden = true
            window = nil
            return
        }
        guard window == nil, isEnabled else { return }
        let shield = UIWindow(windowScene: UIApplication.shared.connectedScenes.first as! UIWindowScene)
        shield.windowLevel = .alert + 1
        let controller = UIViewController()
        controller.view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        shield.rootViewController = controller
        shield.isHidden = false
        window = shield
    }
}
