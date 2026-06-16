import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/browse/data/remote_models.dart';
import 'package:tonari/features/p115/data/p115_client.dart';
import 'package:tonari/features/p115/data/p115_cookie_store.dart';
import 'package:tonari/features/p115/presentation/p115_browser_page.dart';
import 'package:tonari/features/player/data/playback_controller.dart';
import 'package:tonari/features/video/data/video_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _MemoryBackend implements P115CookieBackend {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class _FakeP115Client extends P115Client {
  _FakeP115Client()
    : super(cookieStore: P115CookieStore(backend: _MemoryBackend()));

  final calls = <String>[];

  @override
  Future<List<RemoteEntry>> list(String cid) async {
    return const [
      RemoteEntry(
        id: 'audio',
        path: 'audio',
        name: 'voice.wav',
        kind: RemoteEntryKind.audio,
        sourceId: P115Client.sourceId,
        pickcode: 'pc-audio',
      ),
      RemoteEntry(
        id: 'video',
        path: 'video',
        name: 'movie.mp4',
        kind: RemoteEntryKind.video,
        sourceId: P115Client.sourceId,
        pickcode: 'pc-video',
      ),
    ];
  }

  @override
  Future<ResolvedMediaUrl> resolveAudioUrl(String pickcode) async {
    calls.add('audio:$pickcode');
    return ResolvedMediaUrl(url: Uri.parse('https://audio.test/$pickcode'));
  }

  @override
  Future<ResolvedMediaUrl> resolveVideoUrl(String pickcode) async {
    calls.add('video:$pickcode');
    return ResolvedMediaUrl(url: Uri.parse('http://127.0.0.1/video/$pickcode'));
  }
}

class _FakePlaybackController extends PlaybackController {
  List<PlayableItem> startedItems = const [];

  @override
  PlaybackState build() => PlaybackState.empty;

  @override
  Future<void> startBrowseQueue({
    required List<PlayableItem> items,
    required int initialIndex,
  }) async {
    startedItems = items;
  }
}

class _FakeVideoController extends VideoController {
  PlayableItem? opened;

  @override
  VideoPlaybackState build() => const VideoPlaybackState();

  @override
  Future<void> open(PlayableItem item) async {
    opened = item;
  }
}

void main() {
  testWidgets('resolves p115 audio and video with separate resolvers', (
    tester,
  ) async {
    final client = _FakeP115Client();
    final playback = _FakePlaybackController();
    final video = _FakeVideoController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          p115ClientProvider.overrideWithValue(client),
          playbackControllerProvider.overrideWith(() => playback),
          videoControllerProvider.overrideWith(() => video),
        ],
        child: const MaterialApp(home: P115BrowserPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('voice.wav'));
    await tester.pump();
    final audio = await playback.startedItems.single.resolve();
    expect(audio.url.toString(), 'https://audio.test/pc-audio');

    await tester.tap(find.text('movie.mp4'));
    await tester.pump();
    final openedVideo = video.opened;
    expect(openedVideo, isNotNull);
    final videoUrl = await openedVideo!.resolve();
    expect(videoUrl.url.toString(), 'http://127.0.0.1/video/pc-video');

    expect(client.calls, ['audio:pc-audio', 'video:pc-video']);
  });
}
