import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/browse/data/remote_models.dart';
import 'package:tonari/features/p115/data/p115_cipher.dart';
import 'package:tonari/features/p115/data/p115_client.dart';

void main() {
  test('maps 115 directory response into remote entries', () {
    final entries = P115Client.mapEntries({
      'state': true,
      'data': [
        {'cid': '10', 'n': 'Folder'},
        {'fid': '20', 'n': 'voice.mp3', 's': '100', 'pc': 'pc-audio'},
        {'fid': '21', 'n': 'movie.mkv', 's': 200, 'pc': 'pc-video'},
        {'fid': '22', 'n': 'archive.zip', 's': 300, 'pc': 'pc-other'},
      ],
    });

    expect(entries[0].kind, RemoteEntryKind.folder);
    expect(entries[1].kind, RemoteEntryKind.other);
    expect(entries[2].kind, RemoteEntryKind.video);
    expect(entries[3].kind, RemoteEntryKind.audio);
    expect(entries[3].pickcode, 'pc-audio');
  });

  test('encrypts app downurl payload like p115cipher', () {
    expect(
      P115Cipher.encryptJson({'pickcode': 'abc123'}),
      'C/K77ytKjE5SY30/UtT17jMnyejh5T37Y+9d81OQjzpnjAOCFf4wcD8rdnb1libQRKTXYIemT2bL+larZoLw5pZeGo5VVhAJZ30kBza7gFvthr+fMoV5JdDakSH1ROiHtPjgzw58owP5qcr/mvbf1WOBGkfJwpiFIM9UFR/xlbo=',
    );
  });
}
