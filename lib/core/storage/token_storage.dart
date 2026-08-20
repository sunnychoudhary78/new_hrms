import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _jwtKey = 'jwt_token';
  static const _refreshKey = 'refresh_token';
  static const _fcmKey = 'fcm_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveJwt(String token) async {
    await _storage.write(key: _jwtKey, value: token);
  }

  Future<String?> getJwt() async {
    return await _storage.read(key: _jwtKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshKey);
  }

  Future<void> saveFcm(String token) async {
    print('💾 Saving FCM token: $token');
    await _storage.write(key: _fcmKey, value: token);
  }

  Future<String?> getFcm() async {
    final token = await _storage.read(key: _fcmKey);
    print('📦 Read FCM token from storage: $token');
    return token;
  }

  Future<void> clear() async {
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _refreshKey);
  }
}
