import Foundation
import Synchronization
import Testing
@testable import TonariCore

struct DLsiteWishlistTests {
    private final class Server: Sendable {
        let requests = Mutex<[URLRequest]>([])
        let body: @Sendable (URLRequest) -> String

        init(_ body: @escaping @Sendable (URLRequest) -> String) { self.body = body }

        var send: DLsiteWishlist.Send {
            { request in
                self.requests.withLock { $0.append(request) }
                return (Data(self.body(request).utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
        }
    }

    @Test func readsIdsWithTheSavedCookie() async throws {
        let server = Server { _ in
            #"{"favorites":["RJ2","RJ1"],"discounts":["RJ1"],"sale_start":[],"discount_notices":[],"release_works":[]}"# + "\n\n"
        }
        let ids = try await DLsiteWishlist(cookie: "__DLsite_SID=abc; loginchecked=1", send: server.send).productIds()
        #expect(ids == ["RJ2", "RJ1"])
        let cookie = server.requests.withLock { $0[0].value(forHTTPHeaderField: "Cookie") }
        #expect(cookie?.contains("__DLsite_SID=abc") == true)
    }

    @Test func renewedCookiesReplaceOldOnes() {
        let renewed = HTTPCookie.cookies(
            withResponseHeaderFields: ["Set-Cookie": "__DLsite_SID=new; Path=/; Domain=.dlsite.com, gone=x; Path=/; Expires=Thu, 01 Jan 2000 00:00:00 GMT"],
            for: URL(string: "https://www.dlsite.com/")!
        )
        #expect(DLsiteWishlist.merge("__DLsite_SID=old; gone=1; loginchecked=1", renewed) == "loginchecked=1; __DLsite_SID=new")
    }

    @Test func loginPageMeansExpired() async throws {
        let server = Server { _ in "<!DOCTYPE html><html>login</html>" }
        await #expect(throws: DLsiteWishlist.Failure.expired) {
            try await DLsiteWishlist(cookie: "x=1", send: server.send).productIds()
        }
    }

    @Test func cartModesAddAndRemove() async throws {
        let server = Server { request in
            let body = String(decoding: request.httpBody!, as: UTF8.self)
            return body.contains("RJ9") ? "<result><result_code>-1</result_code><res_msg>已售罄</res_msg></result>" : "<result><result_code>1</result_code></result>"
        }
        let wishlist = DLsiteWishlist(cookie: "x=1", send: server.send)
        try await wishlist.add("RJ1")
        try await wishlist.remove("RJ1")
        await #expect(throws: DLsiteWishlist.Failure.failed("已售罄")) { try await wishlist.add("RJ9") }
        let bodies = server.requests.withLock { $0.map { String(decoding: $0.httpBody!, as: UTF8.self) } }
        #expect(bodies[0] == "mode=wishlist&obj_nocheck=1&product_id=RJ1")
        #expect(bodies[1] == "mode=wishlist_remove&obj_nocheck=1&product_id=RJ1")
    }
}
