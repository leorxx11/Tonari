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
