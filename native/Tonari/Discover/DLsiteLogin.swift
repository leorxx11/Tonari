import SwiftUI
import TonariCore
import WebKit

/// DLsite's own login page in a web view. The app never touches the
/// password: once DLsite sets its signed-in cookie, the cookies are kept
/// and the sheet closes. A private data store means every login starts
/// clean and nothing lingers in the web view.
struct DLsiteLoginSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LoginWebView { cookies, userAgent in
                try! DLsiteAccount.save(cookies, userAgent: userAgent)
                model.wishlist.signedIn()
                model.notices.show("已登录 DLsite")
                dismiss()
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("登录 DLsite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

private struct LoginWebView: UIViewRepresentable {
    let signedIn: ([(name: String, value: String)], String) -> Void

    static let start = URL(string: "https://www.dlsite.com/maniax/login/=/skip_register/1")!

    func makeCoordinator() -> Coordinator { Coordinator(signedIn: signedIn) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: Self.start))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let signedIn: ([(name: String, value: String)], String) -> Void
        private var done = false

        init(signedIn: @escaping ([(name: String, value: String)], String) -> Void) {
            self.signedIn = signedIn
        }

        /// Checked after every page: DLsite lands back on www.dlsite.com
        /// with the signed-in cookie once the login went through.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !done, webView.url?.host() == "www.dlsite.com" else { return }
            Task { @MainActor in
                let cookies = Self.sentToWWW(await webView.configuration.websiteDataStore.httpCookieStore.allCookies())
                guard !done, cookies.contains(where: { $0.name == DLsiteAccount.loginCookie && $0.value != "0" }) else { return }
                done = true
                let userAgent = try! await webView.evaluateJavaScript("navigator.userAgent") as! String
                // How long DLsite keeps the login: the session and its
                // remember-me cookies' expiry ("session" = until the browser closes).
                let expiry = cookies.filter { ["__DLsite_SID", "dlloginjp", "eridjp", "loginchecked", "session_state"].contains($0.name) }
                    .map { "\($0.name)=\($0.expiresDate.map { $0.formatted(.iso8601) } ?? "session")" }
                DiagnosticLog.shared.write("dlsite", "login_succeeded", [
                    "cookies": cookies.map(\.name).joined(separator: ","), "expiry": expiry.joined(separator: " "),
                ])
                signedIn(cookies.map { (name: $0.name, value: $0.value) }, userAgent)
            }
        }

        /// The cookies a browser would send to www.dlsite.com: the site-wide
        /// and www ones (not login.dlsite.com's), one per name with the
        /// www-specific one winning.
        private static func sentToWWW(_ cookies: [HTTPCookie]) -> [HTTPCookie] {
            let applicable = cookies.filter { ["dlsite.com", ".dlsite.com", "www.dlsite.com", ".www.dlsite.com"].contains($0.domain) }
            var byName: [String: HTTPCookie] = [:]
            for cookie in applicable where byName[cookie.name] == nil || cookie.domain.contains("www") {
                byName[cookie.name] = cookie
            }
            return Array(byName.values)
        }
    }
}
