import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStore {
  static const _serverUrl = 'server_url';
  static const _theme = 'theme_mode';
  static const _deepSeekModel = 'deepseek_model';
  static const _deepSeekThinking = 'deepseek_thinking';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<String> getServerUrl() async =>
      await _prefs.getString(_serverUrl) ?? 'http://127.0.0.1:8787/api/v1';

  Future<void> setServerUrl(String value) =>
      _prefs.setString(_serverUrl, value.trim());

  Future<String> getThemeMode() async =>
      await _prefs.getString(_theme) ?? 'system';

  Future<void> setThemeMode(String value) => _prefs.setString(_theme, value);

  Future<String> getDeepSeekModel() async =>
      await _prefs.getString(_deepSeekModel) ?? 'deepseek-v4-pro';

  Future<void> setDeepSeekModel(String value) =>
      _prefs.setString(_deepSeekModel, value);

  Future<bool> getDeepSeekThinking() async =>
      await _prefs.getBool(_deepSeekThinking) ?? false;

  Future<void> setDeepSeekThinking(bool value) =>
      _prefs.setBool(_deepSeekThinking, value);
}
