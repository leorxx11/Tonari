import SwiftUI
import TonariCore

/// TV QR login: scan with the 115 app and confirm there.
struct P115LoginView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var token: P115Auth.Token?
    @State private var status = "正在获取二维码…"
    @State private var expired = false
    @State private var attempt = 0

    private let auth = P115Auth()

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground))
                if let token {
                    AsyncImage(url: token.imageURL) { image in
                        image.resizable().interpolation(.none).scaledToFit().padding(16)
                    } placeholder: {
                        ProgressView()
                    }
                    .opacity(expired ? 0.2 : 1)
                } else {
                    ProgressView()
                }
            }
            .frame(width: 240, height: 240)
            Text(status).font(.headline)
            if expired {
                Button("刷新二维码") {
                    attempt += 1
                }
                .buttonStyle(.borderedProminent)
            }
            Text("打开 115 App，用「扫一扫」扫描二维码，并在手机上确认登录。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.top, 40)
        .navigationTitle("登录 115")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: attempt) { await login() }
    }

    private func login() async {
        expired = false
        token = nil
        status = "正在获取二维码…"
        do {
            let token = try await auth.token()
            self.token = token
            status = "请用 115 App 扫码"
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(2))
                switch try await auth.status(of: token) {
                case .waiting:
                    break
                case .scanned:
                    status = "已扫码，请在手机上确认"
                case .confirmed:
                    status = "登录成功，正在保存…"
                    try await auth.finish(token)
                    DiagnosticLog.shared.write("p115", "login_done")
                    finished()
                    return
                case .expired:
                    status = "二维码已过期，请刷新"
                    expired = true
                    return
                case .canceled:
                    status = "已取消登录"
                    expired = true
                    return
                }
            }
        } catch is CancellationError {
        } catch {
            status = error.localizedDescription
            expired = true
            DiagnosticLog.shared.write("p115", "login_failed", ["error": "\(error)"])
        }
    }

    /// From the browse tab, go on to the file browser; elsewhere, go back.
    private func finished() {
        if model.tab == .browse {
            model.openP115()
        } else {
            dismiss()
        }
    }
}
