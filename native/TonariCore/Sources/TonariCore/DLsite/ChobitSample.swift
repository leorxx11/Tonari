import Foundation
import SwiftSoup

/// A work's audio preview, hosted on chobit (DLsite's sample service): the
/// tracks the circle put up, each a short m4a.
public struct ChobitSample: Codable, Sendable, Equatable {
    public struct Track: Codable, Sendable, Equatable, Identifiable {
        public let title: String
        public let url: URL
        /// As chobit writes it, `mm:ss`.
        public let playtime: String

        public var id: URL { url }
    }

    public let tracks: [Track]

    /// Nil when the work has no audio preview (none at all, or a video one).
    /// Translation editions share the original's preview.
    public static func fetch(_ productId: String, get: @Sendable (URL) async throws -> Data) async throws -> ChobitSample? {
        let api = URL(string: "https://chobit.cc/api/v1/dlsite/embed?workno=\(productId)")!
        guard let embed = try parseEmbed(try await get(api)) else { return nil }
        let tracks = try parseTracks(String(decoding: try await get(embed), as: UTF8.self))
        return tracks.isEmpty ? nil : ChobitSample(tracks: tracks)
    }

    static func parseEmbed(_ data: Data) throws -> URL? {
        struct Response: Decodable {
            struct Work: Decodable {
                let embedUrl: String
                let fileType: String
            }
            let works: [Work]
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: data).works
            .first { $0.fileType == "audio" }
            .flatMap { URL(string: $0.embedUrl) }
    }

    static func parseTracks(_ html: String) throws -> [Track] {
        try SwiftSoup.parse(html).select(".track-list li[data-src]").array().compactMap { item in
            guard let url = URL(string: try item.attr("data-src")) else { return nil }
            return Track(title: try item.attr("data-title"), url: url, playtime: try item.attr("data-playtime"))
        }
    }
}
