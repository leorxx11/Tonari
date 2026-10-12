import UserNotifications
import TonariCore

/// System notifications for downloads that finish or stop while the app is
/// away; in the foreground the banner says it instead. Tapping one opens the
/// work, or the messages for a stop.
final class DownloadNotifications: NSObject, UNUserNotificationCenterDelegate {
    enum Target {
        case work(String)
        case messages
    }

    /// Set by the app to its navigation.
    var open: (Target) -> Void = { _ in }

    override init() {
        super.init()
        // Set before launch finishes, so a tap that launches the app reaches it.
        UNUserNotificationCenter.current().delegate = self
    }

    /// Asks once; later calls return the earlier answer without showing anything.
    func requestAuthorization() {
        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
    }

    func post(title: String, body: String, opening target: Target) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if case .work(let productId) = target { content.userInfo = ["work": productId] }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        DiagnosticLog.shared.write("offline", "notification_posted", ["title": title])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let productId = response.notification.request.content.userInfo["work"] as? String
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.open(productId.map(Target.work) ?? .messages) }
        }
        completionHandler()
    }
}
