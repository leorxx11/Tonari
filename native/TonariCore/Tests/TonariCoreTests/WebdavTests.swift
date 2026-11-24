import Foundation
import GRDB
import Testing
@testable import TonariCore

struct WebdavClientTests {
    static let server = WebdavServer(name: "NAS", scheme: "http", host: "192.168.1.10", port: 5244, basePath: "/dav/", username: "user")

    @Test func parsesPrefixedMultistatusAndDropsTheFolderItself() throws {
        let body = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:multistatus xmlns:D="DAV:">
              <D:response><D:href>/dav/%E9%9F%B3%E5%A3%B0/</D:href>
                <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>
              </D:response>
              <D:response><D:href>/dav/%E9%9F%B3%E5%A3%B0/RJ01000001%20%5B%E3%82%B5%E3%83%BC%E3%82%AF%E3%83%AB%5D/</D:href>
                <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype><D:getlastmodified>Mon, 12 Jan 1998 09:25:56 GMT</D:getlastmodified></D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>
                <D:propstat><D:prop><D:getcontentlength/></D:prop><D:status>HTTP/1.1 404 Not Found</D:status></D:propstat>
              </D:response>
              <D:response><D:href>/dav/%E9%9F%B3%E5%A3%B0/01%20%231.mp3</D:href>
                <D:propstat><D:prop><D:resourcetype/><D:getcontentlength>12345</D:getcontentlength></D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>
              </D:response>
            </D:multistatus>
            """
        let entries = try WebdavClient.entries(Data(body.utf8), in: "/dav/音声", sourceId: "s1")
        #expect(entries.map(\.path) == ["/dav/音声/RJ01000001 [サークル]", "/dav/音声/01 #1.mp3"])
        #expect(entries.map(\.name) == ["RJ01000001 [サークル]", "01 #1.mp3"])
        #expect(entries.map(\.kind) == [.folder, .audio])
        #expect(entries.map(\.size) == [nil, 12345])
        #expect(entries[0].modifiedAt == Date(timeIntervalSince1970: 884_597_156))
        #expect(entries.allSatisfy { $0.sourceId == "s1" && $0.pickcode == nil && $0.id == $0.path })
    }

    @Test func parsesDefaultNamespaceAndAbsoluteHrefs() throws {
        let body = """
            <multistatus xmlns="DAV:">
              <response><href>http://192.168.1.10:5244/dav/</href><propstat><prop><resourcetype><collection/></resourcetype></prop></propstat></response>
              <response><href>http://192.168.1.10:5244/dav/a.vtt</href><propstat><prop><resourcetype/><getcontentlength>9</getcontentlength></prop></propstat></response>
            </multistatus>
            """
        let entries = try WebdavClient.entries(Data(body.utf8), in: "/dav", sourceId: "s1")
        #expect(entries.map(\.path) == ["/dav/a.vtt"])
        #expect(entries.map(\.kind) == [.subtitle])
    }

    @Test func rejectsABodyThatIsNotXML() {
        #expect(throws: WebdavError.notWebdav) {
            try WebdavClient.entries(Data("<html><body>login".utf8), in: "/", sourceId: "s1")
        }
    }

    @Test func encodesEachPathSegment() {
        let client = WebdavClient(server: Self.server, password: "pw")
        #expect(client.url("/dav/音声/01 #1.mp3").absoluteString == "http://192.168.1.10:5244/dav/%E9%9F%B3%E5%A3%B0/01%20%231.mp3")
        #expect(client.url("/dav/RJ01000001", directory: true).absoluteString == "http://192.168.1.10:5244/dav/RJ01000001/")
        #expect(client.url("/", directory: true).absoluteString == "http://192.168.1.10:5244/")
    }

    @Test func mediaCarriesBasicAuthOnlyWithAUsername() {
        let media = WebdavClient(server: Self.server, password: "pw").media("/dav/a.mp3")
        #expect(media.headers.map(\.name) == ["Authorization"])
        #expect(media.headers.map(\.value) == ["Basic dXNlcjpwdw=="])
        #expect(media.expiresAt == nil)
        var anonymous = Self.server
        anonymous.username = ""
        #expect(WebdavClient(server: anonymous, password: nil).media("/dav/a.mp3").headers.isEmpty)
    }

    @Test(arguments: [(nil, "/"), ("", "/"), (" / ", "/"), ("dav", "/dav"), ("/dav/", "/dav"), ("/a/b", "/a/b")] as [(String?, String)])
    func normalizesTheBasePath(basePath: String?, root: String) {
        var server = Self.server
        server.basePath = basePath
        #expect(server.rootPath == root)
    }
}

struct WebdavServerTests {
    let keychain = KeychainStore(service: "com.leo.tonari.tests.\(UUID().uuidString)")

    static let tree: [String: [RemoteEntry]] = [
        "/dav/ASMR": [
            RemoteEntry(id: "/dav/ASMR/RJ01000001", path: "/dav/ASMR/RJ01000001", name: "RJ01000001", kind: .folder, sourceId: "s"),
        ],
        "/dav/ASMR/RJ01000001": [
            RemoteEntry(id: "/dav/ASMR/RJ01000001/本編", path: "/dav/ASMR/RJ01000001/本編", name: "本編", kind: .folder, sourceId: "s"),
            RemoteEntry(id: "/dav/ASMR/RJ01000001/01.mp3.vtt", path: "/dav/ASMR/RJ01000001/01.mp3.vtt", name: "01.mp3.vtt", kind: .subtitle, size: 9, sourceId: "s"),
        ],
        "/dav/ASMR/RJ01000001/本編": [
            RemoteEntry(id: "/dav/ASMR/RJ01000001/本編/01.mp3", path: "/dav/ASMR/RJ01000001/本編/01.mp3", name: "01.mp3", kind: .audio, size: 100, sourceId: "s"),
        ],
    ]

    func importer(_ db: AppDatabase, _ server: WebdavServer, unauthorized: Bool = false) -> RemoteImport {
        RemoteImport(database: db, source: .webdav(
            server,
            list: { path in
                if unauthorized { throw WebdavError.unauthorized }
                return Self.tree[path]!
            },
            download: { _ in Data("WEBVTT\n\n00:00.000 --> 00:01.000\nはい\n".utf8) }
        ))
    }

    func server(_ db: AppDatabase) throws -> WebdavServer {
        let server = WebdavServer(name: "NAS", scheme: "http", host: "nas.local", port: nil, basePath: "/dav", username: "u")
        try db.saveWebdavServer(server, password: "pw", keychain: keychain)
        return server
    }

    @Test func importsWorksByServerPathWithLocalCategoryRules() async throws {
        let db = try AppDatabase.inMemory()
        let server = try server(db)
        let folder = RemoteEntry(id: "/dav/ASMR", path: "/dav/ASMR", name: "ASMR", kind: .folder, sourceId: server.id)
        let imported = try await importer(db, server).importFolder(folder)
        #expect(imported.summary.worksInserted == 1)
        #expect(try await importer(db, server).importSubtitles(imported) == 1)
        let (work, track, source) = try await db.reader.read { db in
            (try Work.fetchOne(db, key: "RJ01000001")!, try Track.fetchOne(db)!, try ImportedFolder.fetchOne(db)!)
        }
        #expect(work.localFolderPath == "/dav/ASMR/RJ01000001")
        #expect(track.filePath == "/dav/ASMR/RJ01000001/本編/01.mp3")
        #expect(track.categoryHint == "main")
        #expect(source.type == "webdav")
        #expect(source.serverId == server.id)
        #expect(source.displayName == "NAS / ASMR")

        let reimported = try await importer(db, server).reimportWork(work)
        #expect(reimported.workIds == ["RJ01000001"])
    }

    @Test func importingTheBasePathNamesTheSourceAfterTheServer() async throws {
        let db = try AppDatabase.inMemory()
        let server = try server(db)
        let root = RemoteEntry(id: "/dav", path: "/dav", name: server.name, kind: .folder, sourceId: server.id)
        let importer = RemoteImport(database: db, source: .webdav(server, list: { _ in [] }, download: { _ in Data() }))
        _ = try await importer.importFolder(root)
        #expect(try await db.reader.read { try ImportedFolder.fetchOne($0)!.displayName } == "NAS")
    }

    @Test func rejectedCredentialsEndTheScan() async throws {
        let db = try AppDatabase.inMemory()
        let server = try server(db)
        let folder = RemoteEntry(id: "/dav/ASMR", path: "/dav/ASMR", name: "ASMR", kind: .folder, sourceId: server.id)
        await #expect(throws: WebdavError.unauthorized) {
            try await importer(db, server, unauthorized: true).importFolder(folder)
        }
    }

    @Test func savingKeepsThePasswordUnlessGivenANewOne() throws {
        let db = try AppDatabase.inMemory()
        var server = try server(db)
        server.name = "Home"
        try db.saveWebdavServer(server, password: nil, keychain: keychain)
        let client = try db.webdavClient(server.id, keychain: keychain)
        #expect(client.server.name == "Home")
        #expect(client.authorization == "Basic " + Data("u:pw".utf8).base64EncodedString())
        #expect(throws: WebdavError.serverGone) { try db.webdavClient("missing", keychain: keychain) }
    }

    @Test func deletingAServerTakesItsWorksVideosAndHistory() async throws {
        let db = try AppDatabase.inMemory()
        let server = try server(db)
        let folder = RemoteEntry(id: "/dav/ASMR", path: "/dav/ASMR", name: "ASMR", kind: .folder, sourceId: server.id)
        _ = try await importer(db, server).importFolder(folder)
        let video = RemoteEntry(id: "/dav/v.mp4", path: "/dav/v.mp4", name: "v.mp4", kind: .video, sourceId: server.id)
        try db.addVideo(PlayableVideo(remote: video, sourceName: server.name))
        let audio = RemoteEntry(id: "/dav/a.mp3", path: "/dav/a.mp3", name: "a.mp3", kind: .audio, sourceId: server.id)
        try PlaybackStore(database: db).recordFile(audio, sourceName: server.name)
        #expect(try await db.reader.read { try WebdavServers.dependents(of: server.id, $0) } == (1, 1))
        #expect(try await db.reader.read { try PlayHistoryEntry.fetchOne($0)!.remoteFile } == audio)

        try db.deleteWebdavServer(server.id, keychain: keychain)
        let counts = try await db.reader.read { db in
            [try Work.fetchCount(db), try Track.fetchCount(db), try ImportedFolder.fetchCount(db), try VideoItem.fetchCount(db),
             try PlayHistoryEntry.fetchCount(db), try WebdavServer.fetchCount(db)]
        }
        #expect(counts == [0, 0, 0, 0, 0, 0])
        #expect(try WebdavServers.password(server.id, keychain: keychain) == nil)
    }
}
