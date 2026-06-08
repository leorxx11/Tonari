import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/browse/data/remote_models.dart';

void main() {
  PlayableItem item(String id) => PlayableItem(
    id: id,
    sourceKind: RemoteSourceKind.p115,
    sourceId: 'p115',
    sourceName: '115 网盘',
    path: id,
    fileName: '$id.mp3',
    kind: RemoteEntryKind.audio,
    resolve: () async =>
        ResolvedMediaUrl(url: Uri.parse('https://example.com')),
  );

  test('browse queue exposes current, previous and next state', () {
    final queue = BrowseQueue(
      items: [item('1'), item('2'), item('3')],
      currentIndex: 1,
    );

    expect(queue.currentItem!.id, '2');
    expect(queue.hasPrevious, isTrue);
    expect(queue.hasNext, isTrue);
  });

  test('browse queue handles last item', () {
    final queue = BrowseQueue(items: [item('1'), item('2')], currentIndex: 1);

    expect(queue.currentItem!.id, '2');
    expect(queue.hasPrevious, isTrue);
    expect(queue.hasNext, isFalse);
  });
}
