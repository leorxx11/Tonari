import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProviderKeyStore {
  ProviderKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _prefix = 'llm_provider_key:';

  Future<String?> read(String providerId) =>
      _storage.read(key: '$_prefix$providerId');

  Future<void> write(String providerId, String value) =>
      _storage.write(key: '$_prefix$providerId', value: value);

  Future<void> delete(String providerId) =>
      _storage.delete(key: '$_prefix$providerId');
}

final providerKeyStoreProvider = Provider<ProviderKeyStore>((ref) {
  return ProviderKeyStore();
});
