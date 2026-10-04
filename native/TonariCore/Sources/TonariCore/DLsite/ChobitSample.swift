import Foundation
import SwiftSoup

/// A work's preview, hosted on chobit (DLsite's sample service): the audio
/// tracks the circle put up, each a short m4a, and any preview videos.
public struct ChobitSample: Codable, Sendable, Equatable {
    public struct Track: Codable, Sendable, Equatable, Identifiable {
        public let title: String
        public let url: URL
        /// As chobit writes it, `mm:ss`.
        public let playtime: String

        public var id: URL { url }
    }

    public struct Video: Codable, Sendable, Equatable, Identifiable {
        public let title: String
        /// The rendition chobit plays by default (720p), else the first.
        public let url: URL
        public let poster: URL?

        public var id: URL { url }
    }

    public let tracks: [Track]
    public let videos: [Video]

    public init(tracks: [Track], videos: [Video]) {
        self.tracks = tracks
        self.videos = videos
    }

    public var isEmpty: Bool { tracks.isEmpty && videos.isEmpty }

    /// Nil when the work has no audio or video preview. Translation
    /// editions share the original's preview.
    public static func fetch(_ productId: String, get: @Sendable (URL) async throws -> Data) async throws -> ChobitSample? {
        let api = URL(string: "https://chobit.cc/api/v1/dlsite/embed?workno=\(productId)")!
        var tracks: [Track] = []
        var videos: [Video] = []
        for embed in try parseEmbeds(try await get(api)) {
            let html = String(decoding: try await get(embed.url), as: UTF8.self)
            switch embed.fileType {
            case "audio": tracks += try parseTracks(html)
            case "video": videos += try parseVideos(html)
            default: continue
            }
        }
        let sample = ChobitSample(tracks: tracks, videos: videos)
        return sample.isEmpty ? nil : sample
    }

    /// Each embed page with its kind (`audio`, `video`, `image`).
    static func parseEmbeds(_ data: Data) throws -> [(fileType: String, url: URL)] {
        struct Response: Decodable {
            struct Work: Decodable {
                let embedUrl: String
                let fileType: String
            }
            let works: [Work]
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: data).works.compactMap { work in
            URL(string: work.embedUrl).map { (work.fileType, $0) }
        }
    }

    static func parseTracks(_ html: String) throws -> [Track] {
        try SwiftSoup.parse(html).select(".track-list li[data-src]").array().compactMap { item in
            guard let url = URL(string: try item.attr("data-src")) else { return nil }
            return Track(title: try item.attr("data-title"), url: url, playtime: try item.attr("data-playtime"))
        }
    }

    static func parseVideos(_ html: String) throws -> [Video] {
        try SwiftSoup.parse(html).select(".player-box[data-title]").array().compactMap { box in
            guard let video = try box.select("video").first(),
                  let source = try video.select("source[data-default]").first() ?? video.select("source").first(),
                  let url = URL(string: try source.attr("src")) else { return nil }
            return Video(title: try box.attr("data-title"), url: url, poster: URL(string: try video.attr("data-poster")))
        }
    }
}
