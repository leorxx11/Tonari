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

    @Test func videoOrNoPreviewIsNil() throws {
        #expect(try ChobitSample.parseEmbed(Data(#"{"count":0,"works":[]}"#.utf8)) == nil)
        #expect(try ChobitSample.parseEmbed(Data(#"{"count":1,"works":[{"embed_url":"https://chobit.cc/embed/x","file_type":"video"}]}"#.utf8)) == nil)
    }
}
