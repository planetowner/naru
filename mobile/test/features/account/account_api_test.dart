import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naru/features/auth/domain/app_user.dart';
import 'package:naru/features/auth/domain/auth_session.dart';
import 'package:naru/features/account/domain/friend_request.dart';
import 'package:naru/features/chat/data/chat_api.dart';
import 'package:naru/features/chat/data/chat_api_exception.dart';

const user = AppUser(
  id: 'maya',
  username: 'Maya',
  displayName: 'Maya 🌿',
  preferredLanguage: 'es',
);
ChatApi apiFor(Future<http.Response> Function(http.Request) handler) => ChatApi(
  client: MockClient(handler),
  baseUri: Uri.parse('https://api.test'),
  accessToken: 'token',
  preferredLanguage: 'en',
);
http.Response jsonResponse(Object? value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'username lookup preserves exact value and returns existing friend state',
    () async {
      final api = apiFor((request) async {
        expect(request.url.queryParameters['username'], 'Maya');
        expect(request.headers['Authorization'], 'Bearer token');
        return jsonResponse({'user': user.toJson(), 'is_friend': true});
      });
      final result = await api.searchUser(' Maya ');
      expect(result!.isFriend, isTrue);
      expect(result.user.displayName, 'Maya 🌿');
      expect(
        await apiFor((_) async => jsonResponse(null)).searchUser('unknown'),
        isNull,
      );
    },
  );

  test('friend request sends only target id and propagates failures', () async {
    final api = apiFor((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/users/friends/maya');
      expect(request.body, isEmpty);
      return jsonResponse({
        'user': user.toJson(),
        'is_friend': false,
        'outgoing_request_id': 'request-1',
      });
    });
    final sent = await api.sendFriendRequest('maya');
    expect(sent.isFriend, isFalse);
    expect(sent.outgoingRequestId, 'request-1');
    await expectLater(
      apiFor((_) async => jsonResponse({}, 500)).sendFriendRequest('maya'),
      throwsA(isA<ChatApiException>()),
    );
  });

  test(
    'request decisions reuse authenticated JSON requests and require 204',
    () async {
      final api = apiFor((request) async {
        expect(request.url.path, '/users/friend-requests/request-1/respond');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer token');
        expect(jsonDecode(request.body), {'decision': 'accept'});
        return http.Response('', 204);
      });
      await api.respondToFriendRequest(
        'request-1',
        FriendRequestDecision.accept,
      );
      await expectLater(
        apiFor(
          (_) async => jsonResponse({}),
        ).respondToFriendRequest('request-1', FriendRequestDecision.decline),
        throwsA(isA<ChatApiException>()),
      );
    },
  );

  test(
    'profile upload reuses create, PUT, complete before profile PATCH',
    () async {
      final calls = <String>[];
      final api = apiFor((request) async {
        calls.add('${request.method} ${request.url.path}');
        switch (request.url.path) {
          case '/media-assets':
            expect(jsonDecode(request.body), containsPair('kind', 'photo'));
            return jsonResponse({
              'media_asset_id': 'photo-id',
              'upload_url': 'https://storage.test/photo.jpg',
              'upload_headers': {'Content-Type': 'image/jpeg'},
            }, 201);
          case '/photo.jpg':
            expect(request.bodyBytes, [1, 2, 3]);
            return http.Response('', 200);
          case '/media-assets/photo-id/complete':
            return jsonResponse({});
          case '/users/me':
            expect(jsonDecode(request.body), {
              'display_name': 'Maya 🌿',
              'preferred_language': 'es',
              'photo_asset_id': 'photo-id',
            });
            return jsonResponse(user.toJson());
          default:
            throw StateError('${request.url}');
        }
      });
      final asset = await api.uploadProfilePhoto(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
      );
      await api.updateProfile(
        displayName: ' Maya 🌿 ',
        preferredLanguage: 'es',
        photoAssetId: asset,
      );
      expect(calls, [
        'POST /media-assets',
        'PUT /photo.jpg',
        'POST /media-assets/photo-id/complete',
        'PATCH /users/me',
      ]);
    },
  );

  test('profile without a new photo preserves its current photo', () async {
    final api = apiFor((request) async {
      expect(jsonDecode(request.body).containsKey('photo_asset_id'), isFalse);
      return jsonResponse(user.toJson());
    });
    await api.updateProfile(displayName: 'Maya', preferredLanguage: 'es');
  });

  test('updated session retains tokens and serializes the new account', () {
    const original = AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      tokenType: 'bearer',
      user: AppUser(
        id: 'maya',
        username: 'Maya',
        displayName: 'Old',
        preferredLanguage: 'ko',
      ),
    );
    final restored = AuthSession.fromJson(original.withUser(user).toJson());
    expect(restored.accessToken, 'access');
    expect(restored.refreshToken, 'refresh');
    expect(restored.user.displayName, 'Maya 🌿');
    expect(restored.user.preferredLanguage, 'es');
  });
}
