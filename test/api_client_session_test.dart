import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whatsapp_responder_app/core/api/api_client.dart';
import 'package:whatsapp_responder_app/core/api/api_exception.dart';
import 'package:whatsapp_responder_app/core/storage/secure_store.dart';

class _MemorySecureStore extends SecureStore {
  String? access = 'expired-access';
  String? refresh = 'refresh-1';

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clearProjectSession() async {
    access = null;
    refresh = null;
  }
}

http.Response _json(int status, Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

void main() {
  test('parallel 401 responses rotate a refresh token only once', () async {
    final store = _MemorySecureStore();
    var refreshCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(jsonDecode(request.body)['refreshToken'], 'refresh-1');
        return _json(200, {
          'data': {
            'accessToken': 'access-2',
            'refreshToken': 'refresh-2',
            'accessExpiresAt': 1000,
            'refreshExpiresAt': 2000,
          },
        });
      }

      if (request.headers['authorization'] == 'Bearer expired-access') {
        return _json(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'expired'},
        });
      }
      return _json(200, {
        'data': {'ok': true},
      });
    });
    final api = ApiClient(
      secureStore: store,
      baseUrl: 'https://example.test/api/v1',
      client: httpClient,
    );

    final results = await Future.wait([
      api.getMap('/one'),
      api.getMap('/two'),
      api.getMap('/three'),
    ]);

    expect(results.every((item) => item['ok'] == true), isTrue);
    expect(refreshCalls, 1);
    expect(store.access, 'access-2');
    expect(store.refresh, 'refresh-2');
    api.close();
  });

  test('temporary refresh errors never erase the durable device session', () async {
    final store = _MemorySecureStore();
    final api = ApiClient(
      secureStore: store,
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return _json(429, {
            'error': {'code': 'RATE_LIMITED', 'message': 'retry later'},
          });
        }
        return _json(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'expired'},
        });
      }),
    );

    await expectLater(
      api.getMap('/status'),
      throwsA(isA<ApiException>()),
    );
    expect(store.refresh, 'refresh-1');
    api.close();
  });

  test('definitively invalid refresh token clears the local device session', () async {
    final store = _MemorySecureStore();
    final api = ApiClient(
      secureStore: store,
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return _json(401, {
            'error': {
              'code': 'INVALID_REFRESH_TOKEN',
              'message': 'invalid refresh',
            },
          });
        }
        return _json(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'expired'},
        });
      }),
    );

    await expectLater(
      api.getMap('/status'),
      throwsA(isA<ApiException>()),
    );
    expect(store.refresh, isNull);
    api.close();
  });

  test('streamed upload reopens the file exactly once after session refresh', () async {
    final store = _MemorySecureStore();
    var openReadCalls = 0;
    var mediaCalls = 0;
    final receivedBodies = <List<int>>[];
    final api = ApiClient(
      secureStore: store,
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return _json(200, {
            'data': {
              'accessToken': 'access-2',
              'refreshToken': 'refresh-2',
              'accessExpiresAt': 1000,
              'refreshExpiresAt': 2000,
            },
          });
        }
        if (request.url.path.endsWith('/media')) {
          mediaCalls++;
          receivedBodies.add(request.bodyBytes);
          if (request.headers['authorization'] == 'Bearer expired-access') {
            return _json(401, {
              'error': {'code': 'UNAUTHORIZED', 'message': 'expired'},
            });
          }
          return _json(201, {
            'data': {
              'id': 7,
              'kind': 'image',
              'mimeType': 'image/jpeg',
              'sizeBytes': 4,
              'originalName': 'photo.jpg',
              'createdAt': 123,
            },
          });
        }
        return _json(404, const {});
      }),
    );

    final asset = await api.uploadMediaStream(
      openRead: () {
        openReadCalls++;
        return Stream<List<int>>.fromIterable(const [
          [1, 2],
          [3, 4],
        ]);
      },
      contentLength: 4,
      kind: 'image',
      mimeType: 'image/jpeg',
      fileName: 'photo.jpg',
    );

    expect(asset.id, 7);
    expect(openReadCalls, 2);
    expect(mediaCalls, 2);
    expect(receivedBodies, [
      [1, 2, 3, 4],
      [1, 2, 3, 4],
    ]);
    api.close();
  });

  test('private auto reply update sends one bounded settings patch', () async {
    final store = _MemorySecureStore()..access = 'access-ok';
    Map<String, dynamic>? requestBody;
    final api = ApiClient(
      secureStore: store,
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/settings');
        requestBody = Map<String, dynamic>.from(jsonDecode(request.body));
        return _json(200, {
          'data': {
            'privateAutoReply': {
              'enabled': true,
              'message': 'أهلًا بك',
              'cooldownMinutes': 720,
            },
          },
        });
      }),
    );

    final result = await api.setPrivateAutoReply(
      enabled: true,
      message: 'أهلًا بك',
    );

    expect(requestBody, {
      'privateAutoReply': {'enabled': true, 'message': 'أهلًا بك'},
    });
    expect((result['privateAutoReply'] as Map)['enabled'], isTrue);
    api.close();
  });
}
