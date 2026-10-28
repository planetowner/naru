import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/auth_session.dart';
import 'auth_exception.dart';
import 'auth_refresh_exception.dart';

final class AuthApi {
  const AuthApi({required http.Client client, required Uri baseUri})
    : _client = client,
      _baseUri = baseUri;

  final http.Client _client;
  final Uri _baseUri;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) => _authenticate('/auth/login', {
    'username': username,
    'password': password,
  }, successStatus: 200);

  Future<AuthSession> register({
    required String username,
    required String password,
    required String passwordConfirmation,
  }) => _authenticate('/auth/register', {
    'username': username,
    'password': password,
    'password_confirmation': passwordConfirmation,
  }, successStatus: 201);

  Future<AuthSession> _authenticate(
    String path,
    Map<String, String> credentials, {
    required int successStatus,
  }) async {
    final http.Response response = await _client.post(
      _baseUri.resolve(path),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(credentials),
    );

    final Map<String, dynamic> responseJson =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == successStatus) {
      return AuthSession.fromJson(responseJson);
    }

    final Object? detail = responseJson['detail'];
    throw AuthException(
      detail is String
          ? detail
          : response.statusCode == 422
          ? 'Check your username and password.'
          : 'Could not sign in. Please try again.',
    );
  }

  Future<AuthSession> refresh({required String refreshToken}) async {
    final http.Response response = await _client.post(
      _baseUri.resolve('/auth/refresh'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    final Object? decodedBody = jsonDecode(response.body);
    if (response.statusCode == 200 && decodedBody is Map<String, dynamic>) {
      return AuthSession.fromJson(decodedBody);
    }

    final String message = decodedBody is Map<String, dynamic>
        ? decodedBody['detail'] as String? ?? 'Session refresh failed.'
        : 'Session refresh failed.';

    throw AuthRefreshException(message, statusCode: response.statusCode);
  }
}
