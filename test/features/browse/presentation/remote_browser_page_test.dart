import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tonari/features/browse/data/remote_models.dart';
import 'package:tonari/features/browse/presentation/remote_browser_page.dart';
import 'package:tonari/features/player/data/playback_controller.dart';
import 'package:tonari/features/video/data/video_controller.dart';
import 'package:tonari/features/video/presentation/video_player_page.dart';

class _FakePlaybackController extends PlaybackController {
  List<PlayableItem> startedItems = const [];
  int startedIndex = -1;

  @override
  PlaybackState build() => PlaybackState.empty;

  @override
  Future<void> startBrowseQueue({
    required List<PlayableItem> items,
    required int initialIndex,
  }) async {
    startedItems = items;
    startedIndex = initialIndex;
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
  const root = RemoteEntry(
    id: 'root',
    path: 'root',
    name: '115 网盘',
    kind: RemoteEntryKind.folder,
    sourceId: 'p115',
  );
  const folder = RemoteEntry(
    id: 'folder',
    path: 'folder',
    name: 'Folder',
    kind: RemoteEntryKind.folder,
    sourceId: 'p115',
  );
  const audio = RemoteEntry(
    id: 'audio',
    path: 'audio',
    name: 'voice.mp3',
    kind: RemoteEntryKind.audio,
    sourceId: 'p115',
    pickcode: 'a',
  );
  const video = RemoteEntry(
    id: 'video',
    path: 'video',
    name: 'movie.mp4',
    kind: RemoteEntryKind.video,
    sourceId: 'p115',
    pickcode: 'v',
  );

  testWidgets('file browser enters folders and shows media icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RemoteBrowserPage(
            sourceKind: RemoteSourceKind.p115,
            sourceId: 'p115',
            sourceName: '115 网盘',
            root: root,
            loadFolder: (entry) async =>
                entry.id == 'root' ? const [folder] : const [audio, video],
            resolveFile: (_) async =>
                ResolvedMediaUrl(url: Uri.parse('https://example.com/media')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.music_note), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.videocam_fill), findsOneWidget);
  });

  testWidgets('tapping audio starts browse queue', (tester) async {
    final fake = _FakePlaybackController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playbackControllerProvider.overrideWith(() => fake)],
        child: MaterialApp(
          home: RemoteBrowserPage(
            sourceKind: RemoteSourceKind.p115,
            sourceId: 'p115',
            sourceName: '115 网盘',
            root: root,
            loadFolder: (_) async => const [audio, video],
            resolveFile: (_) async =>
                ResolvedMediaUrl(url: Uri.parse('https://example.com/media')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('voice.mp3'));
    await tester.pump();

    expect(fake.startedItems.map((e) => e.fileName), ['voice.mp3']);
    expect(fake.startedIndex, 0);
  });

  testWidgets('tapping video opens video player page', (tester) async {
    final fakeVideo = _FakeVideoController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [videoControllerProvider.overrideWith(() => fakeVideo)],
        child: MaterialApp(
          home: RemoteBrowserPage(
            sourceKind: RemoteSourceKind.p115,
            sourceId: 'p115',
            sourceName: '115 网盘',
            root: root,
            loadFolder: (_) async => const [video],
            resolveFile: (_) async =>
                ResolvedMediaUrl(url: Uri.parse('https://example.com/media')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('movie.mp4'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(VideoPlayerPage), findsOneWidget);
    expect(fakeVideo.opened?.fileName, 'movie.mp4');
  });
}
