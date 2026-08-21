import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStore {
  static const _serverUrl = 'server_url';
  static const _theme = 'theme_mode';
  static const _deepSeekModel = 'deepseek_model';
  static const _deepSeekThinking = 'deepseek_thinking';

  /// Stable public HTTPS entrypoint. Android users never type or manage it.
  /// The backend itself remains bound to loopback behind the HTTPS proxy.
  static const defaultServerUrl =
      'https://vmi3452413.tailc13979.ts.net/api/v1';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<String> getServerUrl() async {
    // v0.2.0 intentionally stops trusting previously entered URLs. This avoids
    // stale private/Tailscale-only addresses and keeps onboarding deterministic.
    final saved = (await _prefs.getString(_serverUrl))?.trim();
    if (saved != defaultServerUrl) {
      await _prefs.setString(_serverUrl, defaultServerUrl);
    }
    return defaultServerUrl;
  }

  Future<void> setServerUrl(String value) async {
    // Kept only for backwards source compatibility. Normal UI has no server URL
    // field and the app always returns to the pinned endpoint on next launch.
    await _prefs.setString(_serverUrl, defaultServerUrl);
  }

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
