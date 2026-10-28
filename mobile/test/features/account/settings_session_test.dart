import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naru/core/config/app_config.dart';
import 'package:naru/design_system/app_icons.dart';
import 'package:naru/features/auth/data/auth_session_store.dart';
import 'package:naru/features/auth/domain/app_user.dart';
import 'package:naru/features/auth/domain/auth_session.dart';
import 'package:naru/main.dart';

import 'account_api_test.dart' show jsonResponse;

void main() {
  testWidgets(
    'saving settings updates app locale and persisted session together',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const session = AuthSession(
        accessToken: 'header.eyJleHAiOjQxMDI0NDQ4MDB9.signature',
        refreshToken: 'refresh',
        tokenType: 'bearer',
        user: AppUser(
          id: 'me',
          username: 'june',
          displayName: 'June',
          preferredLanguage: 'en',
        ),
      );
      FlutterSecureStorage.setMockInitialValues({
        'naru.auth_session.v1': jsonEncode(session.toJson()),
      });
      int listRequests = 0;
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/auth/refresh':
            return jsonResponse(session.toJson());
          case '/users':
            listRequests++;
            return jsonResponse([]);
          case '/messages/unread-counts':
            return jsonResponse({
              'counts_by_sender_id': {},
              'total_unread_count': 0,
            });
          case '/users/me':
            final profile = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({...session.user.toJson(), ...profile});
          default:
            throw StateError('Unexpected request: ${request.url}');
        }
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          NaruApp(
            appConfig: AppConfig(apiBaseUri: Uri.parse('http://localhost:1')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(AppIcons.settings));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '준');
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('한국어'));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('채팅'), findsOneWidget);
        expect(find.text('아직 추가한 친구가 없어요.'), findsOneWidget);
        expect(find.text('Settings'), findsNothing);
        final stored = await const AuthSessionStore().load();
        expect(stored!.user.displayName, '준');
        expect(stored.user.preferredLanguage, 'ko');
        expect(stored.accessToken, session.accessToken);
        expect(listRequests, 2);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }, () => client);
    },
  );
}
