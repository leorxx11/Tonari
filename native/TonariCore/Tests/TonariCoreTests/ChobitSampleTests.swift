import Foundation
import Testing
@testable import TonariCore

private func fixture(_ name: String) throws -> Data {
    try Data(contentsOf: Bundle.module.url(forResource: "Fixtures/dlsite/\(name)", withExtension: nil)!)
}

struct ChobitSampleTests {
    @Test func audioEmbedListsItsTracks() async throws {
        let sample = try await ChobitSample.fetch("RJ01702393") { url in
            url.host() == "chobit.cc" && url.path().hasPrefix("/api") ? try fixture("chobit_embed.json") : try fixture("chobit_audio.html")
        }
        let tracks = try #require(sample).tracks
        #expect(tracks.count == 8)
        #expect(tracks[0].title == "01_イキなり会って即尺フェラチオ＆ローション抱き付き耳舐め")
        #expect(tracks[0].playtime == "00:43")
        #expect(tracks[0].url.absoluteString.hasSuffix("_001.m4a"))
    }

    @Test func videoEmbedGivesItsDefaultRendition() async throws {
        let sample = try await ChobitSample.fetch("RJ328940") { url in
            url.host() == "chobit.cc" && url.path().hasPrefix("/api")
                ? Data(#"{"count":2,"works":[{"embed_url":"https://chobit.cc/embed/2ubcd/x","file_type":"video"},{"embed_url":"https://chobit.cc/embed/2ubcd/y","file_type":"image"}]}"#.utf8)
                : try fixture("chobit_video.html")
        }
        let videos = try #require(sample).videos
        #expect(sample?.tracks == [])
        #expect(videos.map(\.title) == ["カルティベーターPV"])
        #expect(videos[0].url.absoluteString.hasSuffix("_8wp6w9.mp4"))
        #expect(videos[0].poster?.absoluteString.hasSuffix("_thumb.jpg") == true)
    }

    @Test func noPreviewIsNil() async throws {
        let sample = try await ChobitSample.fetch("RJ01000001") { _ in Data(#"{"count":0,"works":[]}"#.utf8) }
        #expect(sample == nil)
    }
}
