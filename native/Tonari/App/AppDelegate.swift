import UIKit

/// Portrait everywhere except the video player, which may turn sideways.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientations = UIInterfaceOrientationMask.portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientations
    }

    /// Changes what the app may rotate to and turns to `preferred` now.
    static func allow(_ orientations: UIInterfaceOrientationMask, turningTo preferred: UIInterfaceOrientationMask) {
        self.orientations = orientations
        // The video player's onDisappear also runs while the app is torn
        // down, after its scene has gone; there's nothing left to turn then.
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: preferred))
    }
}
