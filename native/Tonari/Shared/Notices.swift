import Observation
import SwiftUI

/// Outcomes worth a glance, not a tap: a banner slides in at the top and
/// leaves on its own. Failures of background tasks also land in the inbox.
@Observable
final class Notices {
    struct Notice: Equatable {
        enum Kind {
            case success, failure, info
        }

        let id = UUID()
        let text: String
        let kind: Kind
    }

    var current: Notice?

    func show(_ text: String, _ kind: Notice.Kind = .success) {
        current = Notice(text: text, kind: kind)
    }
}

struct NoticeBanner: View {
    let notices: Notices

    var body: some View {
        if let notice = notices.current {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                switch notice.kind {
                case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .failure: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                case .info: Image(systemName: "info.circle.fill").foregroundStyle(.secondary)
                }
                Text(notice.text).font(.subheadline).lineLimit(4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(in: .rect(cornerRadius: 20))
            .padding(.horizontal)
            .contentShape(.rect)
            .onTapGesture { notices.current = nil }
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: notice.id) {
                // Cancelled when a newer notice replaces this one.
                guard (try? await Task.sleep(for: .seconds(notice.kind == .failure ? 4 : 2.5))) != nil else { return }
                notices.current = nil
            }
        }
    }
}

/// Hosts the banner in a window of its own above sheets and full-screen
/// players, which cover anything drawn in the main window. Touches outside
/// the banner fall through to the app.
final class NoticeWindow: UIWindow {
    private static var shared: NoticeWindow?

    static func install(_ notices: Notices) {
        guard shared == nil else { return }
        let window = NoticeWindow(windowScene: UIApplication.shared.connectedScenes.first as! UIWindowScene)
        window.windowLevel = .alert
        let host = UIHostingController(rootView: NoticeHost(notices: notices))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        shared = window
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view === rootViewController?.view ? nil : view
    }
}

private struct NoticeHost: View {
    let notices: Notices
    @AppStorage(Appearance.preferenceKey) private var appearance = Appearance.system

    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                NoticeBanner(notices: notices).animation(.snappy, value: notices.current)
            }
            .preferredColorScheme(appearance.colorScheme)
    }
}
