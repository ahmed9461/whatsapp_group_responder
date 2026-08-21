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
  bool statsBusy = false;
  String? error;
  ThemeMode themeMode = ThemeMode.system;
  String serverUrl = PreferencesStore.defaultServerUrl;
  String statisticsPeriod = '24h';

  Map<String, dynamic> status = {};
  ApiStatistics statistics = ApiStatistics.empty;
  Map<String, dynamic> settings = {};
  ApiWhatsAppStatus whatsappStatus = ApiWhatsAppStatus.empty;
  List<ApiCommand> commands = [];
  List<ApiGroup> groups = [];
  List<ApiApproval> approvals = [];
  List<ApiScheduledCampaign> scheduledCampaigns = [];
  List<ApiBroadcast> broadcasts = [];

  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _eventReconnect;
  Timer? _fallbackRefresh;
  bool _liveRefreshRunning = false;
  bool _liveRefreshQueued = false;
  Future<void>? _resumeInFlight;

  Map<String, dynamic> get deviceAccess {
    final raw = status['device'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  Set<String> get permissions => ((deviceAccess['permissions'] as List?) ?? const [])
      .map((item) => '$item')
      .where((item) => item.isNotEmpty)
      .toSet();

  bool can(String permission) => permissions.contains(permission);

  String get deviceRole => '${deviceAccess['role'] ?? 'unknown'}';

  String get deviceRoleLabel {
    final server = '${deviceAccess['roleLabel'] ?? ''}'.trim();
    if (server.isNotEmpty) return server;
    return switch (deviceRole) {
      'owner' => '👑 مالك',
      'content' => '🧰 مدير محتوى',
      'replies' => '✏️ محرر الردود',
      'viewer' => '👁️ مشاهدة فقط',
      _ => 'جهاز مرتبط',
    };
  }

  String get deviceGroupScopeMode =>
      '${deviceAccess['groupScopeMode'] ?? 'all'}';

  List<int> get deviceGroupIds => ((deviceAccess['groupIds'] as List?) ?? const [])
      .map((item) => item is num ? item.toInt() : int.tryParse('$item') ?? 0)
      .where((item) => item > 0)
      .toList();

  List<ApiGroup> get approvedGroups =>
      groups.where((group) => group.approved).toList();

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
    // v0.2.0 uses one pinned public HTTPS endpoint. Keep this method only so
    // older callers cannot accidentally persist a stale/private server URL.
    serverUrl = PreferencesStore.defaultServerUrl;
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
    scheduledCampaigns = [];
    broadcasts = [];
    status = {};
    statistics = ApiStatistics.empty;
    statisticsPeriod = '24h';
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
      // /status is the authorization bootstrap. Read it first so a restricted
      // device never sprays requests at endpoints it is not allowed to use.
      try {
        status = await api.getStatus();
      } catch (statusError) {
        errors.add(statusError);
        error = '$statusError';
        return;
      }

      final work = <Future<void>>[];

      if (can('commands.read')) {
        work.add(_capture(() async => commands = await api.getCommands(), errors));
      } else {
        commands = [];
      }

      if (can('groups.read')) {
        work.add(_capture(() async => groups = await api.getGroups(), errors));
      } else {
        groups = [];
      }

      if (can('approvals.read')) {
        work.add(
          _capture(() async => approvals = await api.getApprovals(), errors),
        );
      } else {
        approvals = [];
      }

      if (can('statistics.read')) {
        work.add(
          _capture(
            () async => statistics = ApiStatistics.fromJson(
              await api.getStatistics(period: statisticsPeriod),
            ),
            errors,
          ),
        );
      } else {
        statistics = ApiStatistics.empty;
      }

      if (can('settings.read')) {
        work.add(_capture(() async => settings = await api.getSettings(), errors));
      } else {
        settings = {};
      }

      if (can('whatsapp.read')) {
        work.add(
          _capture(
            () async => whatsappStatus =
                ApiWhatsAppStatus.fromJson(await api.getWhatsAppStatus()),
            errors,
          ),
        );
      } else {
        whatsappStatus = ApiWhatsAppStatus.empty;
      }

      if (can('scheduled.read')) {
        work.add(
          _capture(
            () async => scheduledCampaigns = await api.getScheduledCampaigns(),
            errors,
          ),
        );
      } else {
        scheduledCampaigns = [];
      }

      if (can('broadcasts.read')) {
        work.add(
          _capture(() async => broadcasts = await api.getBroadcasts(), errors),
        );
      } else {
        broadcasts = [];
      }

      await Future.wait<void>(work);
      isLinked = (await secureStore.refreshToken) != null;
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
    } catch (operationError) {
      errors.add(operationError);
    }
  }

  Future<void> refreshCommands() async {
    if (!can('commands.read')) return;
    commands = await api.getCommands();
    notifyListeners();
  }

  Future<void> refreshGroups() async {
    if (!can('groups.read')) return;
    groups = await api.getGroups();
    notifyListeners();
  }

  Future<void> refreshApprovals() async {
    if (!can('approvals.read')) return;
    approvals = await api.getApprovals();
    notifyListeners();
  }

  Future<void> refreshStats({String? period}) async {
    if (!can('statistics.read')) return;
    final next = period ?? statisticsPeriod;
    if (!const {'24h', '7d', '30d'}.contains(next)) return;
    statisticsPeriod = next;
    statsBusy = true;
    notifyListeners();
    try {
      statistics =
          ApiStatistics.fromJson(await api.getStatistics(period: next));
    } finally {
      statsBusy = false;
      notifyListeners();
    }
  }

  Future<void> setStatisticsPeriod(String period) =>
      refreshStats(period: period);

  Future<void> refreshWhatsApp() async {
    if (!can('whatsapp.read')) return;
    whatsappStatus =
        ApiWhatsAppStatus.fromJson(await api.getWhatsAppStatus());
    notifyListeners();
  }

  Future<void> refreshScheduled() async {
    if (!can('scheduled.read')) return;
    scheduledCampaigns = await api.getScheduledCampaigns();
    notifyListeners();
  }

  Future<void> refreshBroadcasts() async {
    if (!can('broadcasts.read')) return;
    broadcasts = await api.getBroadcasts();
    notifyListeners();
  }

  Future<void> decideApproval(int id, bool approve) async {
    if (!can('approvals.write')) {
      throw StateError('هذا الجهاز لا يملك صلاحية إدارة الموافقات.');
    }
    try {
      await api.decideApproval(id, approve).timeout(const Duration(seconds: 8));
    } catch (requestError, requestStack) {
      List<ApiApproval> latest;
      try {
        latest = await api.getApprovals().timeout(const Duration(seconds: 5));
      } catch (_) {
        Error.throwWithStackTrace(requestError, requestStack);
      }
      if (latest.any((item) => item.id == id)) {
        Error.throwWithStackTrace(requestError, requestStack);
      }
      approvals = latest;
      notifyListeners();
      unawaited(_refreshAfterApprovalDecision());
      return;
    }

    approvals = approvals.where((item) => item.id != id).toList();
    notifyListeners();
    unawaited(_refreshAfterApprovalDecision());
  }

  Future<void> _refreshAfterApprovalDecision() async {
    try {
      final results = await Future.wait([
        api.getApprovals(),
        api.getGroups(),
      ]);
      approvals = results[0] as List<ApiApproval>;
      groups = results[1] as List<ApiGroup>;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> handleAppResumed() {
    final running = _resumeInFlight;
    if (running != null) return running;
    final operation = _handleAppResumedOnce();
    _resumeInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_resumeInFlight, operation)) _resumeInFlight = null;
    });
  }

  Future<void> _handleAppResumedOnce() async {
    if (!isLinked) return;
    _startLiveUpdates();
    await refreshAll(silent: true);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await preferences.setThemeMode(mode.name);
    notifyListeners();
  }

  void _startLiveUpdates() {
    if (!can('events.read')) return;
    _startEvents();
    _fallbackRefresh?.cancel();
    _fallbackRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isLinked) unawaited(_refreshFromLiveSignal());
    });
  }

  void _startEvents() {
    if (!can('events.read')) return;
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
    if (!isLinked || !can('events.read')) return;
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
