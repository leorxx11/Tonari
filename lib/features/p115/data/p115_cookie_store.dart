import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class P115Cookie {
  const P115Cookie({
    required this.uid,
    required this.cid,
    required this.seid,
    required this.kid,
  });

  final String uid;
  final String cid;
  final String seid;
  final String kid;

  String get header => 'UID=$uid; CID=$cid; SEID=$seid; KID=$kid';

  static P115Cookie parse(String raw) {
    final parts = <String, String>{};
    for (final part in raw.split(';')) {
      final i = part.indexOf('=');
      if (i < 0) continue;
      parts[part.substring(0, i).trim()] = part.substring(i + 1).trim();
    }
    return P115Cookie(
      uid: parts['UID'] ?? '',
      cid: parts['CID'] ?? '',
      seid: parts['SEID'] ?? '',
      kid: parts['KID'] ?? '',
    );
  }

  static P115Cookie fromApiCookie(Map<String, dynamic> json) {
    return P115Cookie(
      uid: '${json['UID']}',
      cid: '${json['CID']}',
      seid: '${json['SEID']}',
      kid: '${json['KID'] ?? ''}',
    );
  }
}

abstract class P115CookieBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class P115SecureCookieBackend implements P115CookieBackend {
  P115SecureCookieBackend({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  // A Keychain item's accessibility is fixed at write time, and delete only
  // matches items written under the same accessibility. Earlier builds may have
  // stored the cookie under a different one (plugin default), leaving an item
  // that reads back but resists a plain delete — and iOS keeps Keychain items
  // across app uninstalls. Delete under every accessibility to clear residue.
  @override
  Future<void> delete(String key) async {
    for (final accessibility in KeychainAccessibility.values) {
      await _storage.delete(
        key: key,
        iOptions: IOSOptions(accessibility: accessibility),
      );
    }
  }
}

class P115CookieStore {
  P115CookieStore({P115CookieBackend? backend})
    : _backend = backend ?? P115SecureCookieBackend();

  final P115CookieBackend _backend;

  static const _key = 'p115_cookie';

  Future<P115Cookie?> read() async {
    final raw = await _backend.read(_key);
    if (raw == null || raw.isEmpty) return null;
    return P115Cookie.parse(raw);
  }

  Future<void> write(P115Cookie cookie) => _backend.write(_key, cookie.header);

  Future<void> clear() => _backend.delete(_key);
}

final p115CookieStoreProvider = Provider<P115CookieStore>((ref) {
  return P115CookieStore();
});

final p115CookieProvider = FutureProvider<P115Cookie?>((ref) {
  return ref.watch(p115CookieStoreProvider).read();
});
