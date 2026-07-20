import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> deleteToken();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'red_sky_backend_bearer_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> writeToken(String token) => _storage.write(
    key: _tokenKey,
    value: token,
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<void> deleteToken() => _storage.delete(
    key: _tokenKey,
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
}
