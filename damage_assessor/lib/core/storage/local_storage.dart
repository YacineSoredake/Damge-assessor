import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// IMPORTANT: this only ever stores the backend session JWT.
/// Subscription status and trial flags must NEVER be cached here —
/// per the spec, those are always fetched live from the backend to
/// prevent a lapsed/expired user from continuing to use the app
/// off a stale local flag.
class LocalStorage {
  LocalStorage._();
  static final LocalStorage instance = LocalStorage._();

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'backend_jwt';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
