import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models.dart';
import '../storage/secure_store.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required this.secureStore,
    required String baseUrl,
    http.Client? client,
  })  : _baseUrl = _normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  final SecureStore secureStore;
  final http.Client _client;
  String _baseUrl;
  Future<bool>? _refreshInFlight;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String value) {
    _baseUrl = _normalizeBaseUrl(value);
  }

  static String _normalizeBaseUrl(String input) {
    var value = input.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.endsWith('/api/v1')) {
      value = '$value/api/v1';
    }
    return value;
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<Map<String, dynamic>> health() async {
    final response = await _client
        .get(_uri('/health'))
        .timeout(const Duration(seconds: 10));
    return _dataMap(response);
  }

  Future<EnrollmentResult> createEnrollment({
    required String deviceName,
    required String deviceInstanceId,
  }) async {
    final response = await _client
        .post(
          _uri('/device-enrollments'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'deviceName': deviceName,
            'platform': 'android',
            'appVersion': '0.1.6',
            'deviceInstanceId': deviceInstanceId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return EnrollmentResult.fromJson(_dataMap(response));
  }

  Future<Map<String, dynamic>> enrollmentStatus(
    String id,
    String enrollmentToken,
  ) async {
    final response = await _client
        .get(
          _uri('/device-enrollments/$id'),
          headers: {'authorization': 'Bearer $enrollmentToken'},
        )
        .timeout(const Duration(seconds: 10));
    return _dataMap(response);
  }

  Future<SessionTokens> claimEnrollment(
    String id,
    String enrollmentToken,
  ) async {
    final response = await _client
        .post(
          _uri('/device-enrollments/$id/claim'),
          headers: {
            ..._jsonHeaders(),
            'authorization': 'Bearer $enrollmentToken',
          },
        )
        .timeout(const Duration(seconds: 15));
    return SessionTokens.fromJson(_dataMap(response));
  }

  Future<Map<String, dynamic>> getStatus() => getMap('/status');

  Future<List<ApiCommand>> getCommands() async {
    return (await getList('/commands')).map(ApiCommand.fromJson).toList();
  }

  Future<List<ApiGroup>> getGroups() async {
    return (await getList('/groups')).map(ApiGroup.fromJson).toList();
  }

  Future<List<ApiApproval>> getApprovals() async {
    return (await getList('/approvals')).map(ApiApproval.fromJson).toList();
  }

  Future<Map<String, dynamic>> getStatistics({String period = '24h'}) {
    final safe = const {'24h', '7d', '30d'}.contains(period) ? period : '24h';
    return getMap('/statistics?period=$safe');
  }

  Future<Map<String, dynamic>> getSettings() => getMap('/settings');

  Future<Map<String, dynamic>> getWhatsAppStatus() {
    return getMap('/whatsapp/status');
  }

  Future<List<ApiScheduledCampaign>> getScheduledCampaigns() async {
    return (await getList('/scheduled-campaigns'))
        .map(ApiScheduledCampaign.fromJson)
        .toList();
  }

  Future<List<ApiBroadcast>> getBroadcasts({int limit = 50}) async {
    return (await getList('/broadcasts?limit=$limit'))
        .map(ApiBroadcast.fromJson)
        .toList();
  }

  Future<ApiCommand> createCommand({
    required String trigger,
    required ApiMessageContent responseContent,
    required String scopeMode,
    required List<int> groupIds,
    int cooldownSeconds = 3,
  }) async {
    final data = await postMap('/commands', {
      'trigger': trigger,
      'responseContent': responseContent.toJson(),
      'scopeMode': scopeMode,
      'groupIds': scopeMode == 'all' ? <int>[] : groupIds,
      'cooldownSeconds': cooldownSeconds,
    });
    return ApiCommand.fromJson(data);
  }

  Future<ApiCommand> updateCommand(
    int id,
    Map<String, dynamic> fields,
  ) async {
    return ApiCommand.fromJson(await patchMap('/commands/$id', fields));
  }

  Future<void> deleteCommand(int id) async {
    await _authorizedRequest('DELETE', '/commands/$id');
  }

  Future<ApiCommand> addAlias(int id, String alias) async {
    return ApiCommand.fromJson(
      await postMap('/commands/$id/aliases', {'alias': alias}),
    );
  }

  Future<ApiCommand> removeAlias(int id, int aliasId) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/commands/$id/aliases/$aliasId',
    );
    return ApiCommand.fromJson(_dataMap(response));
  }

  Future<ApiGroup> setGroupResponses(int id, bool enabled) async {
    return ApiGroup.fromJson(
      await patchMap('/groups/$id', {'responsesEnabled': enabled}),
    );
  }

  Future<Map<String, dynamic>> decideApproval(int id, bool approve) {
    return postMap(
      '/approvals/$id/${approve ? 'approve' : 'reject'}',
      const {},
    );
  }

  Future<Map<String, dynamic>> setMaintenance(bool enabled) {
    return patchMap('/settings', {'maintenanceMode': enabled});
  }

  Future<ApiMediaAsset> uploadMedia({
    required Uint8List bytes,
    required String kind,
    required String mimeType,
    required String fileName,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/media',
      rawBody: bytes,
      extraHeaders: {
        'content-type': mimeType,
        'x-media-kind': kind,
        'x-file-name': fileName,
        'accept': 'application/json',
      },
      timeout: const Duration(seconds: 90),
    );
    return ApiMediaAsset.fromJson(_dataMap(response));
  }

  Future<void> deleteMedia(int id) async {
    await _authorizedRequest('DELETE', '/media/$id');
  }

  Future<ApiScheduledCampaign> createScheduledCampaign({
    required String name,
    required int intervalSeconds,
    required String selectionMode,
    required String targetMode,
    required List<int> groupIds,
    required bool enabled,
  }) async {
    final data = await postMap('/scheduled-campaigns', {
      'name': name,
      'intervalSeconds': intervalSeconds,
      'selectionMode': selectionMode,
      'targetMode': targetMode,
      'groupIds': targetMode == 'all' ? <int>[] : groupIds,
      'enabled': enabled,
    });
    return ApiScheduledCampaign.fromJson(data);
  }

  Future<ApiScheduledCampaign> updateScheduledCampaign(
    int id,
    Map<String, dynamic> fields,
  ) async {
    return ApiScheduledCampaign.fromJson(
      await patchMap('/scheduled-campaigns/$id', fields),
    );
  }

  Future<void> deleteScheduledCampaign(int id) async {
    await _authorizedRequest('DELETE', '/scheduled-campaigns/$id');
  }

  Future<ApiScheduledCampaign> addScheduledMessage(
    int id,
    ApiMessageContent content,
  ) async {
    return ApiScheduledCampaign.fromJson(
      await postMap(
        '/scheduled-campaigns/$id/messages',
        {'content': content.toJson()},
      ),
    );
  }

  Future<ApiScheduledCampaign> deleteScheduledMessage(
    int id,
    int messageId,
  ) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/scheduled-campaigns/$id/messages/$messageId',
    );
    return ApiScheduledCampaign.fromJson(_dataMap(response));
  }

  Future<ApiBroadcast> runScheduledNow(int id) async {
    final data = await postMap('/scheduled-campaigns/$id/run-now', const {});
    final dispatch = data['dispatch'];
    if (dispatch is! Map) {
      throw ApiException('INVALID_RESPONSE', 'Missing dispatch');
    }
    return ApiBroadcast.fromJson(Map<String, dynamic>.from(dispatch));
  }

  Future<ApiBroadcast> createBroadcast({
    required ApiMessageContent content,
    required String targetMode,
    required List<int> groupIds,
  }) async {
    return ApiBroadcast.fromJson(
      await postMap('/broadcasts', {
        'content': content.toJson(),
        'targetMode': targetMode,
        'groupIds': targetMode == 'all' ? <int>[] : groupIds,
      }),
    );
  }

  Future<ApiBroadcast> getBroadcast(int id) async {
    return ApiBroadcast.fromJson(await getMap('/broadcasts/$id'));
  }

  Future<ApiBroadcast> retryBroadcast(int id) async {
    return ApiBroadcast.fromJson(
      await postMap('/broadcasts/$id/retry-failed', const {}),
    );
  }

  Future<ApiBroadcast> cancelBroadcast(int id) async {
    return ApiBroadcast.fromJson(
      await postMap('/broadcasts/$id/cancel', const {}),
    );
  }

  Future<void> deleteBroadcast(int id) async {
    await _authorizedRequest('DELETE', '/broadcasts/$id');
  }

  Future<Map<String, dynamic>> getMap(String path) async {
    return _dataMap(await _authorizedRequest('GET', path));
  }

  Future<List<Map<String, dynamic>>> getList(String path) async {
    final response = await _authorizedRequest('GET', path);
    final data = _decode(response)['data'];
    if (data is! List) {
      throw ApiException('INVALID_RESPONSE', 'Expected a list from $path');
    }
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> postMap(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _dataMap(await _authorizedRequest('POST', path, body: body));
  }

  Future<Map<String, dynamic>> patchMap(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _dataMap(await _authorizedRequest('PATCH', path, body: body));
  }

  Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Uint8List? rawBody,
    Map<String, String>? extraHeaders,
    bool retry = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final accessToken = await secureStore.accessToken;
    if (accessToken == null) {
      throw ApiException('UNAUTHORIZED', 'التطبيق غير مرتبط بالمشروع');
    }

    final request = http.Request(method, _uri(path));
    request.headers.addAll({
      if (rawBody == null) ..._jsonHeaders(),
      'authorization': 'Bearer $accessToken',
      ...?extraHeaders,
    });
    if (body != null) {
      request.body = jsonEncode(body);
    }
    if (rawBody != null) {
      request.bodyBytes = rawBody;
    }

    final streamed = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401 && retry) {
      final refreshed = await refreshSession();
      if (refreshed) {
        return _authorizedRequest(
          method,
          path,
          body: body,
          rawBody: rawBody,
          extraHeaders: extraHeaders,
          retry: false,
          timeout: timeout,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApi(response);
    }
    return response;
  }

  Future<bool> refreshSession() {
    final running = _refreshInFlight;
    if (running != null) return running;

    final operation = _refreshSessionOnce();
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
  }

  Future<bool> _refreshSessionOnce() async {
    final refreshToken = await secureStore.refreshToken;
    if (refreshToken == null) return false;

    try {
      final response = await _client
          .post(
            _uri('/auth/refresh'),
            headers: _jsonHeaders(),
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));
      final tokens = SessionTokens.fromJson(_dataMap(response));
      await secureStore.saveSession(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return true;
    } on ApiException catch (error) {
      // Only a definitive invalid/revoked refresh token should unlink the app.
      // Rate limits and other server errors must keep the durable refresh token
      // so a later retry can recover automatically.
      if (error.statusCode == 401) {
        await secureStore.clearProjectSession();
        return false;
      }
      rethrow;
    }
  }

  Stream<Map<String, dynamic>> events() async* {
    final token = await secureStore.accessToken;
    if (token == null) return;

    final request = http.Request('GET', _uri('/events'))
      ..headers['authorization'] = 'Bearer $token'
      ..headers['accept'] = 'text/event-stream';
    final response = await _client.send(request);

    if (response.statusCode == 401 && await refreshSession()) {
      yield* events();
      return;
    }
    if (response.statusCode != 200) return;

    String? eventName;
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        try {
          final decoded = jsonDecode(line.substring(5).trim());
          if (decoded is Map) {
            yield {
              'type': eventName ?? 'message',
              'data': Map<String, dynamic>.from(decoded),
            };
          }
        } catch (_) {
          // Ignore a malformed SSE message and keep the live stream connected.
        }
      } else if (line.isEmpty) {
        eventName = null;
      }
    }
  }

  Map<String, String> _jsonHeaders() => const {
        'content-type': 'application/json',
        'accept': 'application/json',
      };

  Map<String, dynamic> _dataMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApi(response);
    }
    final data = _decode(response)['data'];
    if (data is! Map) {
      throw ApiException('INVALID_RESPONSE', 'Invalid API response');
    }
    return Map<String, dynamic>.from(data);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);
    if (decoded is! Map) {
      throw ApiException('INVALID_RESPONSE', 'Invalid JSON response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Never _throwApi(http.Response response) {
    try {
      final error = _decode(response)['error'];
      if (error is Map) {
        throw ApiException(
          '${error['code'] ?? 'HTTP_${response.statusCode}'}',
          '${error['message'] ?? 'Request failed'}',
          statusCode: response.statusCode,
        );
      }
    } on FormatException {
      // Fall through to a generic HTTP error when the response is not JSON.
    }
    throw ApiException(
      'HTTP_${response.statusCode}',
      'Request failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  void close() => _client.close();
}
