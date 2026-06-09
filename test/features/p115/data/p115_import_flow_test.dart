import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/db/database.dart';
import 'package:tonari/features/browse/data/remote_models.dart';
import 'package:tonari/features/library/data/import_service.dart';
import 'package:tonari/features/library/data/metadata_enrichment.dart';
import 'package:tonari/features/library/data/work_image_cache.dart';
import 'package:tonari/features/p115/data/p115_client.dart';
import 'package:tonari/features/p115/data/p115_cookie_store.dart';
import 'package:tonari/features/p115/data/p115_folder_scanner.dart';
import 'package:tonari/features/p115/data/p115_import_flow.dart';

void main() {
  test(
    'scanner maps p115 RJ folder into pickcode-backed scan result',
    () async {
      final client = _FakeP115Client({
        '0': [_folder('series', 'まとめ')],
        'series': [_folder('rj', 'RJ123456')],
        'rj': [
          _folder('audio', '音声'),
          _file('cover', 'cover.jpg', RemoteEntryKind.image, 'pc-cover'),
          _file('readme', 'readme.txt', RemoteEntryKind.text, 'pc-readme'),
        ],
        'audio': [
          _file('audio-1', '01.wav', RemoteEntryKind.audio, 'pc-audio'),
          _file('video-1', 'movie.mp4', RemoteEntryKind.video, 'pc-video'),
          _file('sub-1', '01.wav.vtt', RemoteEntryKind.subtitle, 'pc-vtt'),
          _file('sub-2', '01.srt', RemoteEntryKind.subtitle, 'pc-srt'),
        ],
      });

      final scan = await P115FolderScanner(client).scan(_folder('0', '115 网盘'));

      expect(scan.works, hasLength(1));
      expect(scan.filesScanned, 6);
      final work = scan.works.single;
      expect(work.productId, 'RJ123456');
      expect(work.audios.single.path, 'pc-audio');
      expect(work.audios.single.relativePath, '音声/01.wav');
      expect(work.videos.single.path, 'pc-video');
      expect(work.videos.single.relativePath, '音声/movie.mp4');
      expect(work.subtitles.single.path, 'pc-vtt');
      expect(work.subtitles.single.relativePath, '音声/01.wav.vtt');
      expect(work.others.map((f) => f.fileName), contains('01.srt'));
    },
  );

  test(
    'import flow stores p115 snapshot and updates same relative path',
    () async {
      final db = TonariDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final client = _FakeP115Client(
        {
          'rj': [
            _file('audio-1', '01.wav', RemoteEntryKind.audio, 'pc-audio'),
            _file('video-1', 'movie.mp4', RemoteEntryKind.video, 'pc-video'),
            _file('sub-1', '01.wav.vtt', RemoteEntryKind.subtitle, 'pc-vtt'),
          ],
        },
        bytes: {'pc-vtt': utf8.encode(_vtt)},
      );
      final flow = P115ImportFlow(
        db: db,
        client: client,
        importer: ImportService(db),
        enrichment: _NoopEnrichment(),
      );
      final folder = _folder('rj', 'RJ999999');

      final first = await flow.importFolder(folder: folder);

      expect(first.worksInserted, 1);
      final importedFolder = await db.select(db.importedFolders).getSingle();
      expect(importedFolder.type, 'p115');
      expect(importedFolder.serverId, P115Client.sourceId);
      expect(importedFolder.remotePath, 'rj');

      var track = await db.select(db.tracks).getSingle();
      expect(track.filePath, 'pc-audio');
      expect(track.relativePath, '01.wav');
      final video = await (db.select(
        db.workFiles,
      )..where((f) => f.fileKind.equals('video'))).getSingle();
      expect(video.filePath, 'pc-video');
      expect(video.fileKind, 'video');
      final subtitle = await db.select(db.subtitles).getSingle();
      expect(subtitle.filePath, 'pc-vtt');

      await db.customStatement(
        'UPDATE tracks SET last_position_ms = ?, play_count = ? WHERE id = ?',
        [7000, 2, track.id],
      );
      client.rows['rj'] = [
        _file('audio-2', '01.wav', RemoteEntryKind.audio, 'pc-audio-2'),
        _file('video-2', 'movie.mp4', RemoteEntryKind.video, 'pc-video-2'),
        _file('sub-1', '01.wav.vtt', RemoteEntryKind.subtitle, 'pc-vtt'),
      ];

      final second = await flow.importFolder(folder: folder);

      expect(second.worksUpdated, 1);
      track = await db.select(db.tracks).getSingle();
      expect(track.filePath, 'pc-audio-2');
      expect(track.lastPositionMs, 7000);
      expect(track.playCount, 2);
      final updatedVideo = await (db.select(
        db.workFiles,
      )..where((f) => f.fileKind.equals('video'))).getSingle();
      expect(updatedVideo.filePath, 'pc-video-2');
    },
  );
}

const _vtt = '''
WEBVTT

00:00:00.000 --> 00:00:01.000
hello
''';

RemoteEntry _folder(String id, String name) {
  return RemoteEntry(
    id: id,
    path: id,
    name: name,
    kind: RemoteEntryKind.folder,
    sourceId: P115Client.sourceId,
  );
}

RemoteEntry _file(
  String id,
  String name,
  RemoteEntryKind kind,
  String pickcode,
) {
  return RemoteEntry(
    id: id,
    path: id,
    name: name,
    kind: kind,
    size: 100,
    pickcode: pickcode,
    sourceId: P115Client.sourceId,
  );
}

class _FakeP115Client extends P115Client {
  _FakeP115Client(this.rows, {this.bytes = const {}})
    : super(cookieStore: P115CookieStore(backend: _MemoryCookieBackend()));

  final Map<String, List<RemoteEntry>> rows;
  final Map<String, List<int>> bytes;

  @override
  Future<List<RemoteEntry>> list(String cid) async => rows[cid] ?? const [];

  @override
  Future<List<int>> getBytesByPickcode(String pickcode) async {
    return bytes[pickcode]!;
  }
}

class _MemoryCookieBackend implements P115CookieBackend {
  String? value;

  @override
  Future<void> delete(String key) async {
    value = null;
  }

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {
    this.value = value;
  }
}

class _NoopEnrichment implements MetadataEnrichmentService {
  @override
  Future<void> enrichBatch(
    Iterable<String> productIds, {
    MetadataProgress? onProgress,
  }) async {}

  @override
  Future<void> enrichOne(
    String productId, {
    bool force = false,
    ImageCacheProgress? onImageProgress,
  }) async {}

  @override
  Future<void> enrichPending() async {}

  @override
  Future<void> refreshImages(
    String productId, {
    ImageCacheProgress? onImageProgress,
  }) async {}
}
