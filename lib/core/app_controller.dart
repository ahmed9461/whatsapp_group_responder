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
  ApiStatistics statistics = ApiStatistics.empty;
  Map<String, dynamic> settings = {};
  ApiWhatsAppStatus whatsappStatus = ApiWhatsAppStatus.empty;
  List<ApiCommand> commands = [];
  List<ApiGroup> groups = [];
  List<ApiApproval> approvals = [];

  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _eventReconnect;
  Timer? _fallbackRefresh;
  bool _liveRefreshRunning = false;
  bool _liveRefreshQueued = false;

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
      _startLiveUpdates();
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
    _startLiveUpdates();
    notifyListeners();
  }

  Future<void> unlinkLocal() async {
    await secureStore.clearProjectSession();
    await _events?.cancel();
    _eventReconnect?.cancel();
    _fallbackRefresh?.cancel();
    isLinked = false;
    commands = [];
    groups = [];
    approvals = [];
    status = {};
    statistics = ApiStatistics.empty;
    settings = {};
    whatsappStatus = ApiWhatsAppStatus.empty;
    notifyListeners();
  }

  Future<void> refreshAll({bool silent = false}) async {
    if (!silent) {
      busy = true;
      error = null;
      notifyListeners();
    }

    final errors = <Object>[];
    try {
      await Future.wait<void>([
        _capture(() async => status = await api.getStatus(), errors),
        _capture(() async => commands = await api.getCommands(), errors),
        _capture(() async => groups = await api.getGroups(), errors),
        _capture(() async => approvals = await api.getApprovals(), errors),
        _capture(
          () async =>
              statistics = ApiStatistics.fromJson(await api.getStatistics()),
          errors,
        ),
        _capture(() async => settings = await api.getSettings(), errors),
        _capture(
          () async => whatsappStatus =
              ApiWhatsAppStatus.fromJson(await api.getWhatsAppStatus()),
          errors,
        ),
      ]);

      final hasRefreshToken = (await secureStore.refreshToken) != null;
      isLinked = hasRefreshToken;
      error = errors.isEmpty ? null : '${errors.first}';
    } finally {
      if (!silent) busy = false;
      notifyListeners();
    }
  }

  Future<void> _capture(
    Future<void> Function() operation,
    List<Object> errors,
  ) async {
    try {
      await operation();
    } catch (e) {
      errors.add(e);
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
    statistics = ApiStatistics.fromJson(await api.getStatistics());
    notifyListeners();
  }

  Future<void> refreshWhatsApp() async {
    whatsappStatus = ApiWhatsAppStatus.fromJson(await api.getWhatsAppStatus());
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await preferences.setThemeMode(mode.name);
    notifyListeners();
  }

  void _startLiveUpdates() {
    _startEvents();
    _fallbackRefresh?.cancel();
    _fallbackRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isLinked) unawaited(_refreshFromLiveSignal());
    });
  }

  void _startEvents() {
    _events?.cancel();
    _eventReconnect?.cancel();
    _events = api.events().listen(
      (_) => unawaited(_refreshFromLiveSignal()),
      onDone: _scheduleEventReconnect,
      onError: (_) => _scheduleEventReconnect(),
    );
  }

  Future<void> _refreshFromLiveSignal() async {
    if (!isLinked) return;
    if (_liveRefreshRunning) {
      _liveRefreshQueued = true;
      return;
    }

    _liveRefreshRunning = true;
    try {
      do {
        _liveRefreshQueued = false;
        await refreshAll(silent: true);
      } while (_liveRefreshQueued && isLinked);
    } finally {
      _liveRefreshRunning = false;
    }
  }

  void _scheduleEventReconnect() {
    _eventReconnect?.cancel();
    if (!isLinked) return;
    _eventReconnect = Timer(const Duration(seconds: 5), _startEvents);
  }

  @override
  void dispose() {
    _events?.cancel();
    _eventReconnect?.cancel();
    _fallbackRefresh?.cancel();
    api.close();
    super.dispose();
  }
}
