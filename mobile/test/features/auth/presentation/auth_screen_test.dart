import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/design_system/components/components.dart';
import 'package:naru/features/auth/data/auth_exception.dart';
import 'package:naru/features/auth/presentation/auth_screen.dart';

import '../../../support/load_app_fonts.dart';

Finder input(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppTextField && w.labelText == label),
  matching: find.byType(TextFormField),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Future<void> pumpAuth(
    WidgetTester tester, {
    AuthSubmit? onSubmit,
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 44, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: AuthScreen(
          onSubmit:
              onSubmit ??
              ({
                required username,
                required password,
                displayName,
                passwordConfirmation,
                preferredLanguage,
              }) async {},
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/brand/naru-symbol.png'),
        tester.element(find.byType(AuthScreen)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSignUp(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Sign up'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String confirmation = ' secret ',
    String displayName = '  June 🌿  ',
  }) async {
    await tester.enterText(input('Username'), '  june  ');
    if (input('Name').evaluate().isNotEmpty) {
      await tester.enterText(input('Name'), displayName);
    }
    await tester.enterText(input('Password'), ' secret ');
    if (input('Confirm password').evaluate().isNotEmpty) {
      await tester.enterText(input('Confirm password'), confirmation);
    }
    await tester.pump();
  }

  Future<void> finishLanguage(WidgetTester tester) async {
    await tester.tap(find.text('Español'));
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, 'Start chatting'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sign in uses existing fields and preserves password whitespace',
    (tester) async {
      Map<String, String?>? submitted;
      await pumpAuth(
        tester,
        onSubmit:
            ({
              required username,
              required password,
              displayName,
              passwordConfirmation,
              preferredLanguage,
            }) async {
              submitted = {
                'username': username,
                'name': displayName,
                'password': password,
                'confirmation': passwordConfirmation,
              };
            },
      );
      expect(find.byType(AppTextField), findsNWidgets(2));
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );
      await fill(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(submitted, {
        'username': 'june',
        'name': null,
        'password': ' secret ',
        'confirmation': null,
      });
    },
  );

  testWidgets(
    'mismatch blocks signup and rechecks when either password changes',
    (tester) async {
      int calls = 0;
      await pumpAuth(
        tester,
        onSubmit:
            ({
              required username,
              required password,
              displayName,
              passwordConfirmation,
              preferredLanguage,
            }) async {
              calls++;
            },
      );
      await openSignUp(tester);
      expect(find.byType(AppTextField), findsNWidgets(4));
      await fill(tester, confirmation: 'secret');
      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(input('Password'), 'secret');
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsNothing);
      await tester.enterText(input('Password'), 'changed');
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(input('Confirm password'), 'changed');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(calls, 0);
      await finishLanguage(tester);
      expect(calls, 1);
      expect(find.widgetWithText(AppButton, 'Log in'), findsOneWidget);
    },
  );

  testWidgets('successful signup sends confirmation and closes signup route', (
    tester,
  ) async {
    Map<String, String?>? submitted;
    await pumpAuth(
      tester,
      onSubmit:
          ({
            required username,
            required password,
            displayName,
            passwordConfirmation,
            preferredLanguage,
          }) async {
            submitted = {
              'username': username,
              'name': displayName,
              'password': password,
              'confirmation': passwordConfirmation,
              'language': preferredLanguage,
            };
          },
    );
    await openSignUp(tester);
    await fill(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
    await finishLanguage(tester);
    expect(submitted, {
      'username': 'june',
      'name': 'June 🌿',
      'password': ' secret ',
      'confirmation': ' secret ',
      'language': 'es',
    });
    expect(find.widgetWithText(AppButton, 'Log in'), findsOneWidget);
  });

  testWidgets(
    'signup requires a name and counts Unicode characters consistently',
    (tester) async {
      await pumpAuth(tester);
      await openSignUp(tester);
      await fill(tester, displayName: '   ');
      expect(find.byType(AppTextField), findsNWidgets(4));
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );

      await tester.enterText(input('Name'), '🌿' * 101);
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Use 100 characters or fewer.'), findsOneWidget);
      expect(find.byType(AppSelectionTile), findsNothing);

      await tester.enterText(input('Name'), '   ');
      await tester.pump();
      expect(find.text('Enter your name.'), findsOneWidget);
      await tester.enterText(input('Name'), '🌿' * 100);
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSelectionTile), findsNWidgets(8));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(input('Name')).controller!.text,
        '🌿' * 100,
      );
    },
  );

  testWidgets(
    'submission disables inputs and duplicate requests then allows retry',
    (tester) async {
      final pending = Completer<void>();
      int calls = 0;
      await pumpAuth(
        tester,
        onSubmit:
            ({
              required username,
              required password,
              displayName,
              passwordConfirmation,
              preferredLanguage,
            }) {
              calls++;
              return pending.future;
            },
      );
      await openSignUp(tester);
      await fill(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Español'));
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Start chatting'));
      await tester.pump();
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);
      expect(
        tester
            .widgetList<AppTextField>(find.byType(AppTextField))
            .every((w) => !w.enabled),
        isTrue,
      );
      await tester.tap(find.byType(AppButton));
      expect(calls, 1);
      pending.completeError(
        const AuthException('This username is already taken'),
      );
      await tester.pumpAndSettle();
      expect(find.text('This username is already taken'), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<AppSelectionTile>(
              find.widgetWithText(AppSelectionTile, 'Español'),
            )
            .onTap,
        isNotNull,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.enterText(input('Username'), 'another-user');
      await tester.pump();
      expect(find.text('This username is already taken'), findsNothing);
    },
  );

  testWidgets('password visibility is independent and retains text', (
    tester,
  ) async {
    await pumpAuth(tester);
    await openSignUp(tester);
    await fill(tester);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    final password = find.descendant(
      of: input('Password'),
      matching: find.byType(TextField),
    );
    final confirm = find.descendant(
      of: input('Confirm password'),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    expect(tester.widget<TextField>(confirm).obscureText, isTrue);
    expect(tester.widget<TextField>(password).controller!.text, ' secret ');
    await tester.tap(find.byTooltip('Show confirm password'));
    await tester.pump();
    expect(tester.widget<TextField>(confirm).obscureText, isFalse);
  });

  testWidgets('invalid username is blocked and back preserves login inputs', (
    tester,
  ) async {
    int calls = 0;
    await pumpAuth(
      tester,
      onSubmit:
          ({
            required username,
            required password,
            displayName,
            passwordConfirmation,
            preferredLanguage,
          }) async {
            calls++;
          },
    );
    await fill(tester);
    await openSignUp(tester);
    await fill(tester);
    await tester.enterText(input('Username'), 'x' * 51);
    await tester.tap(find.widgetWithText(AppButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Use 50 characters or fewer.'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(input('Username')).controller!.text,
      '  june  ',
    );
    expect(
      tester.widget<TextFormField>(input('Password')).controller!.text,
      ' secret ',
    );
  });

  testWidgets('failed transport is recoverable without losing signup fields', (
    tester,
  ) async {
    await pumpAuth(
      tester,
      onSubmit:
          ({
            required username,
            required password,
            displayName,
            passwordConfirmation,
            preferredLanguage,
          }) async {
            throw Exception('connection failed');
          },
    );
    await openSignUp(tester);
    await fill(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Continue'));
    await tester.pumpAndSettle();
    await finishLanguage(tester);
    expect(
      find.text('Could not complete the request. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(input('Confirm password'), findsOneWidget);
    expect(tester.widget<AppButton>(find.byType(AppButton)).isLoading, isFalse);
  });

  testWidgets('short viewport keeps both forms scrollable', (tester) async {
    await pumpAuth(tester);
    await tester.binding.setSurfaceSize(const Size(320, 400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Sign up'));
    await openSignUp(tester);
    await fill(tester);
    await tester.ensureVisible(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AppButton).hitTestable(), findsOneWidget);
  });

  testWidgets('keyboard and larger text leave signup submit reachable', (
    tester,
  ) async {
    await pumpAuth(tester, textScale: 1.6);
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Sign up'));
    await openSignUp(tester);
    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await fill(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AppButton).hitTestable(), findsOneWidget);
  });

  testWidgets(
    'eight languages remain selectable on a small screen with large text',
    (tester) async {
      await pumpAuth(tester, textScale: 1.6);
      await tester.binding.setSurfaceSize(const Size(320, 560));
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Sign up'));
      await openSignUp(tester);
      await fill(tester);
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Continue'));
      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();
      for (final label in [
        '한국어',
        '日本語',
        '中文（简体）',
        'English',
        'Español',
        'Français',
        'Deutsch',
        'Italiano',
      ]) {
        final tile = find.widgetWithText(AppSelectionTile, label);
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(tester.widget<AppSelectionTile>(tile).selected, isTrue);
        expect(
          tester
              .widgetList<AppSelectionTile>(find.byType(AppSelectionTile))
              .where((tile) => tile.selected)
              .length,
          1,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Start chatting'),
      );
      expect(
        find.widgetWithText(AppButton, 'Start chatting').hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets('auth screens keep the shared layout with signup name input', (
    tester,
  ) async {
    await pumpAuth(tester);
    final firstField = find.byType(AppTextField).first;
    expect(tester.getTopLeft(firstField).dy, closeTo(523, 4));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../design_system/goldens/login.png'),
    );
    await openSignUp(tester);
    await fill(tester, displayName: 'June');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byType(AppTextField).first).dy,
      closeTo(124, 1),
    );
    expect(tester.getBottomLeft(find.byType(AppButton)).dy, closeTo(786, 1));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../design_system/goldens/auth-signup.png'),
    );
    await tester.tap(find.widgetWithText(AppButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSelectionTile), findsNWidgets(8));
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../design_system/goldens/auth-language.png'),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(input('Password')).controller!.text,
      ' secret ',
    );
    await tester.tap(find.widgetWithText(AppButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppSelectionTile>(
            find.widgetWithText(AppSelectionTile, 'Español'),
          )
          .selected,
      isTrue,
    );
  });
}
