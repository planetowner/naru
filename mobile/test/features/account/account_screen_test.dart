import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naru/core/l10n/app_strings.dart';
import 'package:naru/design_system/app_icons.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/design_system/components/components.dart';
import 'package:naru/features/account/presentation/add_friend_screen.dart';
import 'package:naru/features/account/presentation/settings_screen.dart';
import 'package:naru/features/account/presentation/user_tile.dart';
import 'package:naru/features/auth/domain/app_language.dart';
import 'package:naru/features/auth/domain/app_user.dart';

import '../../support/localized_test_app.dart';
import '../../support/load_app_fonts.dart';
import 'account_api_test.dart' show apiFor, jsonResponse, user;

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'keyboard search shows shared row, add once becomes check, new search clears old result',
    (tester) async {
      int adds = 0;
      final pending = Completer<http.Response>();
      final api = apiFor((request) async {
        if (request.method == 'POST') {
          adds++;
          return pending.future;
        }
        return jsonResponse(
          request.url.queryParameters['username'] == 'Maya'
              ? {'user': user.toJson(), 'is_friend': false}
              : null,
        );
      });
      await tester.pumpWidget(
        LocalizedTestApp(
          theme: AppTheme.light,
          home: AddFriendScreen(chatApi: api),
        ),
      );
      expect(find.text('Search'), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'Maya');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byType(UserTile), findsOneWidget);
      expect(find.text('@Maya'), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.add));
      await tester.pump();
      expect(adds, 1);
      expect(
        tester
            .widget<AppRoundIconButton>(find.byType(AppRoundIconButton).last)
            .onPressed,
        isNull,
      );
      pending.complete(jsonResponse(user.toJson()));
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIcons.check), findsOneWidget);
      expect(find.byIcon(AppIcons.add), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'unknown');
      await tester.pump();
      expect(find.byType(UserTile), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('No user found.'), findsOneWidget);
    },
  );

  testWidgets(
    'already added results show check and failed add remains retryable',
    (tester) async {
      bool added = false;
      final api = apiFor(
        (request) async => request.method == 'POST'
            ? jsonResponse({}, 500)
            : jsonResponse({'user': user.toJson(), 'is_friend': added}),
      );
      await tester.pumpWidget(
        LocalizedTestApp(
          theme: AppTheme.light,
          home: AddFriendScreen(chatApi: api),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'Maya');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(AppIcons.add));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not complete the request. Please try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.add), findsOneWidget);
      added = true;
      await tester.enterText(find.byType(TextFormField), 'Maya');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIcons.check), findsOneWidget);
    },
  );

  testWidgets(
    'settings stages language and name until Save; cancel does not update',
    (tester) async {
      final requests = <http.Request>[];
      AppUser? saved;
      final api = apiFor((request) async {
        requests.add(request);
        return jsonResponse(user.toJson());
      });
      await tester.pumpWidget(
        LocalizedTestApp(
          theme: AppTheme.light,
          home: SettingsScreen(
            user: user,
            chatApi: api,
            onSaved: (value) async {
              saved = value;
            },
          ),
        ),
      );
      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSelectionTile), findsNWidgets(8));
      await tester.tap(find.text('한국어'));
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('한국어'), findsOneWidget);
      expect(requests, isEmpty);
      await tester.enterText(find.byType(TextFormField).first, ' ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your name.'), findsOneWidget);
      expect(requests, isEmpty);
      await tester.enterText(find.byType(TextFormField).first, 'New name');
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(requests.single.body, contains('"preferred_language":"ko"'));
      expect(requests.single.body, contains('"display_name":"New name"'));
      expect(saved!.toJson(), user.toJson());
    },
  );

  testWidgets('settings fits all supported languages with the keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = apiFor((_) async => throw StateError('Should not save'));
    for (final language in AppLanguage.values) {
      await tester.pumpWidget(
        LocalizedTestApp(
          theme: AppTheme.light,
          language: language.code,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: const EdgeInsets.only(bottom: 330)),
            child: child!,
          ),
          home: SettingsScreen(
            key: ValueKey(language),
            user: user,
            chatApi: api,
            onSaved: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(stringsForLanguage(language.code).settings),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
