import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'api/api_client.dart';
import 'models.dart';
import 'storage/preferences_store.dart';
import 'storage/secure_store.dart';

class AppController extends ChangeNotifier {
  final secureStore = SecureStore();
  final preferences = PreferencesStore();

  late ApiClient api;
  bool isLinked = false;
  bool busy = false;
  String? error;
  ThemeMode themeMode = ThemeMode.system;
  String serverUrl = 'http://127.0.0.1:8787/api/v1';

  Map<String, dynamic> status = {};
  Map<String, dynamic> statistics = {};
  Map<String, dynamic> settings = {};
  Map<String, dynamic> whatsappStatus = {};
  List<ApiCommand> commands = [];
  List<ApiGroup> groups = [];
  List<ApiApproval> approvals = [];

  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _eventReconnect;

  Future<void> initialize() async {
    serverUrl = await preferences.getServerUrl();
    themeMode = switch (await preferences.getThemeMode()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    api = ApiClient(secureStore: secureStore, baseUrl: serverUrl);
    isLinked = (await secureStore.refreshToken) != null;
    if (isLinked) {
      await refreshAll(silent: true);
      _startEvents();
    }
    notifyListeners();
  }

  Future<String> ensureDeviceInstanceId() async {
    final existing = await secureStore.deviceInstanceId;
    if (existing != null && existing.length >= 12) return existing;
    final random = Random.secure();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final value =
        'android-${List.generate(32, (_) => chars[random.nextInt(chars.length)]).join()}';
    await secureStore.saveDeviceInstanceId(value);
    return value;
  }

  Future<void> setServerUrl(String value) async {
    serverUrl = value.trim();
    await preferences.setServerUrl(serverUrl);
    api.setBaseUrl(serverUrl);
    notifyListeners();
  }

  Future<void> completeLink(SessionTokens tokens) async {
    await secureStore.saveSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    isLinked = true;
    await refreshAll();
    _startEvents();
    notifyListeners();
  }

  Future<void> unlinkLocal() async {
    await secureStore.clearProjectSession();
    await _events?.cancel();
    _eventReconnect?.cancel();
    isLinked = false;
    commands = [];
    groups = [];
    approvals = [];
    status = {};
    statistics = {};
    settings = {};
    whatsappStatus = {};
    notifyListeners();
  }

  Future<void> refreshAll({bool silent = false}) async {
    if (!silent) {
      busy = true;
      error = null;
      notifyListeners();
    }
    try {
      final values = await Future.wait<Object>([
        api.getStatus(),
        api.getCommands(),
        api.getGroups(),
        api.getApprovals(),
        api.getStatistics(),
        api.getSettings(),
        api.getWhatsAppStatus(),
      ]);
      status = values[0] as Map<String, dynamic>;
      commands = values[1] as List<ApiCommand>;
      groups = values[2] as List<ApiGroup>;
      approvals = values[3] as List<ApiApproval>;
      statistics = values[4] as Map<String, dynamic>;
      settings = values[5] as Map<String, dynamic>;
      whatsappStatus = values[6] as Map<String, dynamic>;
      isLinked = true;
    } catch (e) {
      error = '$e';
      if ((await secureStore.refreshToken) == null) isLinked = false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshCommands() async {
    commands = await api.getCommands();
    notifyListeners();
  }

  Future<void> refreshGroups() async {
    groups = await api.getGroups();
    notifyListeners();
  }

  Future<void> refreshApprovals() async {
    approvals = await api.getApprovals();
    notifyListeners();
  }

  Future<void> refreshStats() async {
    statistics = await api.getStatistics();
    notifyListeners();
  }

  Future<void> refreshWhatsApp() async {
    whatsappStatus = await api.getWhatsAppStatus();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await preferences.setThemeMode(mode.name);
    notifyListeners();
  }

  void _startEvents() {
    _events?.cancel();
    _eventReconnect?.cancel();
    _events = api.events().listen(
      (_) => refreshAll(silent: true),
      onDone: _scheduleEventReconnect,
      onError: (_) => _scheduleEventReconnect(),
    );
  }

  void _scheduleEventReconnect() {
    _eventReconnect?.cancel();
    if (!isLinked) return;
    _eventReconnect =
        Timer(const Duration(seconds: 5), _startEvents);
  }

  @override
  void dispose() {
    _events?.cancel();
    _eventReconnect?.cancel();
    api.close();
    super.dispose();
  }
}
