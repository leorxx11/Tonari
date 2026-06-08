import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WebdavPasswordStore {
  WebdavPasswordStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _prefix = 'webdav_password:';

  Future<String?> read(String serverId) =>
      _storage.read(key: '$_prefix$serverId');

  Future<void> write(String serverId, String value) =>
      _storage.write(key: '$_prefix$serverId', value: value);

  Future<void> delete(String serverId) =>
      _storage.delete(key: '$_prefix$serverId');
}

final webdavPasswordStoreProvider = Provider<WebdavPasswordStore>((ref) {
  return WebdavPasswordStore();
});
