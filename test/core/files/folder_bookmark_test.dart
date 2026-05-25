import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/core/files/folder_bookmark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('tonari/folder_bookmark');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('create forwards url and returns bookmark', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'create');
      expect(call.arguments, {'url': 'file:///mock/folder'});
      return 'fake-bookmark-base64';
    });

    final bookmark = await FolderBookmark.create('file:///mock/folder');
    expect(bookmark, 'fake-bookmark-base64');
  });

  test('resolve returns path and isStale', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'resolve');
      return {'url': '/mock/File Provider Storage/folder', 'isStale': true};
    });

    final r = await FolderBookmark.resolve('fake-bookmark');
    expect(r.url, '/mock/File Provider Storage/folder');
    expect(r.isStale, true);
  });

  test('release forwards url', () async {
    String? releasedUrl;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'release');
      releasedUrl = (call.arguments as Map)['url'] as String;
      return null;
    });

    await FolderBookmark.release('file:///mock/folder');
    expect(releasedUrl, 'file:///mock/folder');
  });
}
