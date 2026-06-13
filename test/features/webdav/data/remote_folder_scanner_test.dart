import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/webdav/data/remote_folder_scanner.dart';
import 'package:tonari/features/webdav/data/webdav_client.dart';

void main() {
  const config = WebdavConfig(scheme: 'https', host: 'example.com');

  test('skips root RJ folder without listing it', () async {
    final client = _FakeWebdavClient({
      '/dav/RJ111111': [
        const WebdavEntry(
          name: '01.wav',
          path: '/dav/RJ111111/01.wav',
          isDir: false,
          size: 100,
        ),
      ],
    });

    final scan = await RemoteFolderScanner(
      client,
    ).scan(config, '/dav/RJ111111', skipProductIds: {'RJ111111'});

    expect(scan.works, isEmpty);
    expect(scan.filesScanned, 0);
    expect(scan.skippedExisting, 1);
    expect(client.calls, isEmpty);
  });
}

class _FakeWebdavClient extends WebdavClient {
  _FakeWebdavClient(this.rows);

  final Map<String, List<WebdavEntry>> rows;
  final List<String?> calls = [];

  @override
  Future<List<WebdavEntry>> list(WebdavConfig config, [String? dirPath]) async {
    calls.add(dirPath);
    return rows[dirPath] ?? const [];
  }
}
