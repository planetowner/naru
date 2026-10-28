import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naru/features/auth/data/auth_api.dart';
import 'package:naru/features/auth/data/auth_exception.dart';
import 'package:naru/features/auth/data/auth_refresh_exception.dart';

void main() {
  const String username = 'test-user';
  const String displayName = 'June 🌿';
  const String password = 'test-password';
  const String userId = '11111111-1111-4111-8111-111111111111';

  test('login sends the expected request and parses the session', () async {
    final MockClient client = MockClient((http.Request request) async {
      expect(request.method, 'POST');
      expect(request.url, Uri.parse('http://localhost:8000/auth/login'));
      expect(request.headers['Accept'], 'application/json');
      expect(request.headers['Content-Type'], 'application/json');
      expect(jsonDecode(request.body), <String, dynamic>{
        'username': username,
        'password': password,
      });

      return http.Response(
        jsonEncode({
          'access_token': 'test-token',
          'refresh_token': 'test-refresh-token',
          'token_type': 'bearer',
          'user': {
            'id': userId,
            'username': username,
            'display_name': 'June',
            'preferred_language': 'ko',
          },
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    final AuthApi authApi = AuthApi(
      client: client,
      baseUri: Uri.parse('http://localhost:8000'),
    );

    final session = await authApi.login(username: username, password: password);

    expect(session.accessToken, 'test-token');
    expect(session.refreshToken, 'test-refresh-token');
    expect(session.tokenType, 'bearer');
    expect(session.user.id, userId);
    expect(session.user.username, username);
    expect(session.user.displayName, 'June');
    expect(session.user.preferredLanguage, 'ko');
  });

  test('login exposes the backend detail for a 401 response', () async {
    final MockClient client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode({'detail': 'Invalid username or password'}),
        401,
        headers: const {'content-type': 'application/json'},
      );
    });

    final AuthApi authApi = AuthApi(
      client: client,
      baseUri: Uri.parse('http://localhost:8000'),
    );

    expect(
      () => authApi.login(username: username, password: password),
      throwsA(
        isA<AuthException>().having(
          (AuthException error) => error.message,
          'message',
          'Invalid username or password',
        ),
      ),
    );
  });

  test('registration sends confirmation and parses the same session', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/auth/register');
      expect(jsonDecode(request.body), {
        'username': username,
        'password': password,
        'display_name': displayName,
        'password_confirmation': password,
        'preferred_language': 'es',
      });
      return http.Response(
        jsonEncode({
          'access_token': 'registered-token',
          'refresh_token': 'registered-refresh',
          'token_type': 'bearer',
          'user': {
            'id': userId,
            'username': username,
            'display_name': displayName,
            'preferred_language': 'es',
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = AuthApi(
      client: client,
      baseUri: Uri.parse('http://localhost:8000'),
    );
    final session = await api.register(
      username: username,
      password: password,
      displayName: displayName,
      passwordConfirmation: password,
      preferredLanguage: 'es',
    );
    expect(session.accessToken, 'registered-token');
    expect(session.refreshToken, 'registered-refresh');
    expect(session.user.displayName, displayName);
    expect(session.user.preferredLanguage, 'es');
  });

  for (final entry in {
    400: 'Passwords do not match',
    409: 'This username is already taken',
  }.entries) {
    test(
      'registration exposes ${entry.key} without creating a session',
      () async {
        final api = AuthApi(
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode({'detail': entry.value}), entry.key),
          ),
          baseUri: Uri.parse('http://localhost:8000'),
        );
        expect(
          () => api.register(
            username: username,
            password: password,
            displayName: displayName,
            passwordConfirmation: password,
            preferredLanguage: 'es',
          ),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              entry.value,
            ),
          ),
        );
      },
    );
  }

  test('structured validation errors show a readable message', () async {
    final api = AuthApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': [
              {
                'loc': ['body', 'username'],
                'msg': 'String should have at most 50 characters',
              },
            ],
          }),
          422,
        ),
      ),
      baseUri: Uri.parse('http://localhost:8000'),
    );
    expect(
      () => api.register(
        username: 'x' * 51,
        password: password,
        displayName: displayName,
        passwordConfirmation: password,
        preferredLanguage: 'es',
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Check your username and password.',
        ),
      ),
    );
  });

  test('refresh exchanges the refresh token for a complete session', () async {
    final MockClient client = MockClient((http.Request request) async {
      expect(request.method, 'POST');
      expect(request.url, Uri.parse('http://localhost:8000/auth/refresh'));
      expect(jsonDecode(request.body), <String, dynamic>{
        'refresh_token': 'old-refresh-token',
      });

      return http.Response(
        jsonEncode({
          'access_token': 'new-access-token',
          'refresh_token': 'new-refresh-token',
          'token_type': 'bearer',
          'user': {
            'id': userId,
            'username': username,
            'display_name': 'June',
            'preferred_language': 'ko',
          },
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    final AuthApi authApi = AuthApi(
      client: client,
      baseUri: Uri.parse('http://localhost:8000'),
    );

    final session = await authApi.refresh(refreshToken: 'old-refresh-token');

    expect(session.accessToken, 'new-access-token');
    expect(session.refreshToken, 'new-refresh-token');
    expect(session.user.id, userId);
  });

  test('refresh exposes an unauthorized refresh token', () async {
    final MockClient client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode({'detail': 'Could not refresh session'}),
        401,
        headers: const {'content-type': 'application/json'},
      );
    });
    final AuthApi authApi = AuthApi(
      client: client,
      baseUri: Uri.parse('http://localhost:8000'),
    );

    expect(
      () => authApi.refresh(refreshToken: 'invalid-refresh-token'),
      throwsA(
        isA<AuthRefreshException>()
            .having(
              (AuthRefreshException error) => error.statusCode,
              'statusCode',
              401,
            )
            .having(
              (AuthRefreshException error) => error.message,
              'message',
              'Could not refresh session',
            ),
      ),
    );
  });
}
