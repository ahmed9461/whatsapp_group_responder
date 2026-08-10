import 'dart:convert';
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
            'appVersion': '0.1.0',
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

  Future<List<ApiCommand>> getCommands() async =>
      (await getList('/commands')).map(ApiCommand.fromJson).toList();

  Future<List<ApiGroup>> getGroups() async =>
      (await getList('/groups')).map(ApiGroup.fromJson).toList();

  Future<List<ApiApproval>> getApprovals() async =>
      (await getList('/approvals')).map(ApiApproval.fromJson).toList();

  Future<Map<String, dynamic>> getStatistics() => getMap('/statistics');
  Future<Map<String, dynamic>> getSettings() => getMap('/settings');
  Future<Map<String, dynamic>> getWhatsAppStatus() =>
      getMap('/whatsapp/status');

  Future<ApiCommand> createCommand({
    required String trigger,
    required String responseText,
    int cooldownSeconds = 3,
    List<String> scopes = const ['global'],
  }) async {
    final data = await postMap('/commands', {
      'trigger': trigger,
      'responseText': responseText,
      'cooldownSeconds': cooldownSeconds,
      'scopes': scopes,
    });
    return ApiCommand.fromJson(data);
  }

  Future<ApiCommand> updateCommand(
    int id,
    Map<String, dynamic> fields,
  ) async {
    final data = await patchMap('/commands/$id', fields);
    return ApiCommand.fromJson(data);
  }

  Future<void> deleteCommand(int id) async {
    await _authorizedRequest('DELETE', '/commands/$id');
  }

  Future<ApiCommand> addAlias(int id, String alias) async {
    final data = await postMap('/commands/$id/aliases', {'alias': alias});
    return ApiCommand.fromJson(data);
  }

  Future<ApiCommand> removeAlias(int id, int aliasId) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/commands/$id/aliases/$aliasId',
    );
    return ApiCommand.fromJson(_dataMap(response));
  }

  Future<ApiGroup> setGroupResponses(int id, bool enabled) async {
    final data = await patchMap(
      '/groups/$id',
      {'responsesEnabled': enabled},
    );
    return ApiGroup.fromJson(data);
  }

  Future<Map<String, dynamic>> decideApproval(
    int id,
    bool approve,
  ) =>
      postMap('/approvals/$id/${approve ? 'approve' : 'reject'}', const {});

  Future<Map<String, dynamic>> setMaintenance(bool enabled) =>
      patchMap('/settings', {'maintenanceMode': enabled});

  Future<Map<String, dynamic>> getMap(String path) async =>
      _dataMap(await _authorizedRequest('GET', path));

  Future<List<Map<String, dynamic>>> getList(String path) async {
    final response = await _authorizedRequest('GET', path);
    final decoded = _decode(response);
    final data = decoded['data'];
    if (data is! List) {
      throw ApiException('INVALID_RESPONSE', 'Expected a list from $path');
    }
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> postMap(
    String path,
    Map<String, dynamic> body,
  ) async =>
      _dataMap(await _authorizedRequest('POST', path, body: body));

  Future<Map<String, dynamic>> patchMap(
    String path,
    Map<String, dynamic> body,
  ) async =>
      _dataMap(await _authorizedRequest('PATCH', path, body: body));

  Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    final access = await secureStore.accessToken;
    if (access == null) {
      throw ApiException('UNAUTHORIZED', 'التطبيق غير مرتبط بالمشروع');
    }

    final request = http.Request(method, _uri(path));
    request.headers.addAll({
      ..._jsonHeaders(),
      'authorization': 'Bearer $access',
    });
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401 && retry) {
      if (await refreshSession()) {
        return _authorizedRequest(method, path, body: body, retry: false);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApi(response);
    }
    return response;
  }

  Future<bool> refreshSession() async {
    final refresh = await secureStore.refreshToken;
    if (refresh == null) return false;

    try {
      final response = await _client
          .post(
            _uri('/auth/refresh'),
            headers: _jsonHeaders(),
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(const Duration(seconds: 15));
      final tokens = SessionTokens.fromJson(_dataMap(response));
      await secureStore.saveSession(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return true;
    } on ApiException {
      await secureStore.clearProjectSession();
      return false;
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
        final raw = line.substring(5).trim();
        try {
          final data = jsonDecode(raw);
          if (data is Map) {
            yield {
              'type': eventName ?? 'message',
              'data': Map<String, dynamic>.from(data),
            };
          }
        } catch (_) {
          // Ignore a malformed event without dropping the whole stream.
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
    final decoded = _decode(response);
    final data = decoded['data'];
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
      final decoded = _decode(response);
      final error = decoded['error'];
      if (error is Map) {
        throw ApiException(
          '${error['code'] ?? 'HTTP_${response.statusCode}'}',
          '${error['message'] ?? 'Request failed'}',
          statusCode: response.statusCode,
        );
      }
    } on FormatException {
      // Fall through.
    }
    throw ApiException(
      'HTTP_${response.statusCode}',
      'Request failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  void close() => _client.close();
}
