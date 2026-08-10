import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _access = 'wgr_access_token';
  static const _refresh = 'wgr_refresh_token';
  static const _instance = 'wgr_device_instance_id';
  static const _deepSeekKey = 'deepseek_api_key';

  final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  Future<String?> get accessToken => _storage.read(key: _access);
  Future<String?> get refreshToken => _storage.read(key: _refresh);
  Future<String?> get deviceInstanceId => _storage.read(key: _instance);
  Future<String?> get deepSeekApiKey => _storage.read(key: _deepSeekKey);

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _access, value: accessToken);
    await _storage.write(key: _refresh, value: refreshToken);
  }

  Future<void> saveDeviceInstanceId(String value) =>
      _storage.write(key: _instance, value: value);

  Future<void> saveDeepSeekApiKey(String value) async {
    if (value.trim().isEmpty) {
      await _storage.delete(key: _deepSeekKey);
    } else {
      await _storage.write(key: _deepSeekKey, value: value.trim());
    }
  }

  Future<void> clearProjectSession() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}
