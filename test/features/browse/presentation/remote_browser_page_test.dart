import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonari/core/prefs/shared_prefs_provider.dart';
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

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

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

  testWidgets('tapping video starts playback without opening full screen', (
    tester,
  ) async {
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

    expect(fakeVideo.opened?.fileName, 'movie.mp4');
    expect(find.byType(VideoPlayerPage), findsNothing);
  });

  testWidgets('remote browser hides import action in browse mode', (
    tester,
  ) async {
    await tester.pumpWidget(_app(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.byTooltip('导入此目录到媒体库'), findsNothing);
  });

  testWidgets('remote browser shows import action in import mode', (
    tester,
  ) async {
    await tester.pumpWidget(_app(prefs: prefs, importFolder: (_, _) async {}));
    await tester.pumpAndSettle();

    expect(find.byTooltip('导入此目录到媒体库'), findsOneWidget);
  });
}

Widget _app({
  required SharedPreferences prefs,
  RemoteFolderAction? importFolder,
}) {
  const root = RemoteEntry(
    id: 'root',
    path: '/',
    name: 'Remote',
    kind: RemoteEntryKind.folder,
    sourceId: 'remote',
  );
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      home: RemoteBrowserPage(
        sourceKind: RemoteSourceKind.webdav,
        sourceId: 'remote',
        sourceName: 'Remote',
        root: root,
        loadFolder: (_) async => const [],
        resolveFile: (_) async => ResolvedMediaUrl(url: Uri.parse('https://x')),
        importFolder: importFolder,
      ),
    ),
  );
}
