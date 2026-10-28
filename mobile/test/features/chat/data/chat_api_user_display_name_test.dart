import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naru/features/auth/domain/app_user.dart';
import 'package:naru/features/chat/data/chat_api.dart';

void main() {
  test(
    'uses only display_name even when an old response contains an alias',
    () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/users');

        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': '11111111-1111-4111-8111-111111111111',
              'username': 'junebabo',
              'display_name': 'Lia',
              'viewer_display_name': '애기🤍',
              'profile_image_url': null,
              'preferred_language': 'ko',
            },
          ]),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });
      final ChatApi chatApi = ChatApi(
        client: client,
        baseUri: Uri.parse('https://api.example.com'),
        accessToken: 'test-token',
        preferredLanguage: 'en',
      );

      final List<AppUser> users = await chatApi.listUsers();

      expect(users.single.displayName, 'Lia');
      expect(users.single.toJson().containsKey('viewer_display_name'), isFalse);
    },
  );

  test('old stored user data cannot restore a viewer-specific alias', () {
    final user = AppUser.fromJson({
      'id': '11111111-1111-4111-8111-111111111111',
      'username': 'junebabo',
      'display_name': 'Saved Name',
      'viewer_display_name': 'Old Alias',
      'preferred_language': 'ko',
    });
    final restored = AppUser.fromJson(user.toJson());
    expect(restored.displayName, 'Saved Name');
    expect(restored.toJson().containsKey('viewer_display_name'), isFalse);
  });
}
