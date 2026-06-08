import 'package:flutter_test/flutter_test.dart';
import 'package:tonari/features/p115/data/p115_cookie_store.dart';

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

void main() {
  test('writes, reads, and clears 115 cookie', () async {
    final store = P115CookieStore(backend: _MemoryBackend());
    const cookie = P115Cookie(uid: 'u', cid: 'c', seid: 's', kid: 'k');

    await store.write(cookie);
    final read = await store.read();

    expect(read!.header, 'UID=u; CID=c; SEID=s; KID=k');

    await store.clear();
    expect(await store.read(), isNull);
  });
}
