import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/p115/data/p115_client.dart';
import 'package:tonari/features/player/data/playback_controller.dart';

void main() {
  ({Future<String> Function() name, Future<void> Function() probe}) webdav({
    required bool reachable,
  }) => (
    name: () async => 'NAS',
    probe: () async {
      if (!reachable) throw Exception('timeout');
    },
  );

  test('local failures stay out of the inbox', () async {
    expect(await describePlayError(Exception('x')), (
      '无法播放：Exception: x',
      null,
    ));
  });

  test('115 errors are attributed to 115', () async {
    expect(await describePlayError(const P115AuthExpiredException()), (
      '115 登录已失效，请重新登录',
      '115',
    ));
    expect((await describePlayError(const P115BlockedException())).$2, '115');
  });

  test('an unreachable WebDAV server is named in the message', () async {
    expect(
      await describePlayError(Exception('x'), webdav: webdav(reachable: false)),
      ('WebDAV「NAS」连不上，请检查网络或服务器是否开机', 'NAS'),
    );
  });

  test('a reachable WebDAV server keeps the raw error', () async {
    expect(
      await describePlayError(Exception('x'), webdav: webdav(reachable: true)),
      ('无法播放：Exception: x', 'NAS'),
    );
  });
}
