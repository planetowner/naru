import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:naru/core/config/app_config.dart';
import 'package:naru/core/l10n/app_strings.dart';
import 'package:naru/features/auth/domain/app_language.dart';
import 'package:naru/features/chat/domain/chat_message.dart';
import 'package:naru/features/chat/presentation/chat_date_formatter.dart';
import 'package:naru/features/chat/presentation/chat_message_labels.dart';
import 'package:naru/features/chat/presentation/read_receipt_formatter.dart';
import 'package:naru/features/chat/presentation/chat_voice_call_screen.dart';
import 'package:naru/main.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/features/auth/presentation/auth_screen.dart';
import 'package:naru/features/auth/data/auth_exception.dart';
import 'package:naru/features/chat/presentation/chat_conversation_view.dart';
import '../../support/localized_test_app.dart';
import '../../support/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  test('device regions resolve to the eight supported languages', () {
    for (final code in [
      'ko-KR',
      'ja-JP',
      'zh-TW',
      'en-GB',
      'es-MX',
      'fr-CA',
      'de-AT',
      'it-CH',
    ]) {
      expect(
        AppLanguage.fromCode(code).locale.languageCode,
        code.split('-').first,
      );
    }
    expect(
      AppLanguage.resolveLocales([const Locale('ar')], []),
      const Locale('en'),
    );
    expect(AppLanguage.resolveLocales(null, []), const Locale('en'));
  });

  test('specified labels and placeholders are preserved', () {
    final ko = stringsForLanguage('ko');
    final zh = stringsForLanguage('zh-CN');
    final en = stringsForLanguage('en');
    expect([en.username, ko.username, zh.username], ['Username', '아이디', '用户名']);
    expect(ko.replyToName('친구🤍'), '친구🤍에게 답장');
    expect(zh.replyToName('Ana'), '回复Ana');
    expect(en.photoCount(1), '1 photo');
    expect(en.photoCount(3), '3 photos');
    expect(ko.photoCount(17), '사진 17장');
    expect(zh.photoCount(17), '17 张照片');
  });

  test('calendar formatting uses actual years, months, days and weekdays', () {
    final ko = stringsForLanguage('ko');
    final zh = stringsForLanguage('zh-CN');
    expect(
      formatChatDate(DateTime(2026, 7, 11), strings: ko),
      '2026년 7월 11일 토요일',
    );
    expect(
      formatChatDate(DateTime(2026, 7, 11), strings: zh),
      '2026年7月11日 星期六',
    );
    expect(
      formatChatDate(DateTime(2028, 2, 29), strings: ko),
      '2028년 2월 29일 화요일',
    );
    expect(
      formatChatDate(DateTime(2028, 2, 29), strings: zh),
      '2028年2月29日 星期二',
    );
    expect(formatChatMonth(DateTime(2031, 12), ko), '2031년 12월');
    expect(formatChatMonth(DateTime(2031, 12), zh), '2031 十二月');
    expect(ko.calendarWeekdays.split(','), ['일', '월', '화', '수', '목', '금', '토']);
    expect(zh.calendarWeekdays.split(','), ['日', '一', '二', '三', '四', '五', '六']);
    for (final language in AppLanguage.values) {
      final strings = stringsForLanguage(language.code);
      expect(strings.calendarMonths.split(','), hasLength(12));
      expect(strings.calendarWeekdays.split(','), hasLength(7));
      expect(
        formatChatDate(DateTime(2031, 12, 19), strings: strings),
        contains('2031'),
      );
    }
  });

  test(
    'read receipts keep elapsed weeks after thirty days in all languages',
    () {
      final now = DateTime(2026, 10, 28, 12);
      for (final language in AppLanguage.values) {
        final s = stringsForLanguage(language.code);
        for (final (elapsed, expected) in [
          (const Duration(seconds: 59), s.seenNow),
          (const Duration(minutes: 1), s.seenMinutes(1)),
          (const Duration(hours: 1), s.seenHours(1)),
          (const Duration(days: 1), s.seenYesterday),
          (const Duration(days: 2), s.seenDays(2)),
          (const Duration(days: 7), s.seenLastWeek),
          (const Duration(days: 14), s.seenWeeks(2)),
          (const Duration(days: 30), s.seenWeeks(4)),
          (const Duration(days: 400), s.seenWeeks(57)),
        ]) {
          expect(
            formatReadReceipt(
              readAt: now.subtract(elapsed),
              now: now,
              strings: s,
            ),
            expected,
          );
        }
      }
    },
  );

  test(
    'reply summaries use kind without translating a matching text message',
    () {
      final ko = stringsForLanguage('ko');
      const photo = ChatReplyReference(
        messageId: '1',
        senderId: 'a',
        content: 'Photo',
        messageType: 'photo',
        photoCount: 3,
      );
      const text = ChatReplyReference(
        messageId: '2',
        senderId: 'a',
        content: 'Photo',
        messageType: 'text',
      );
      expect(replyPreviewLabel(photo, ko), '사진 3장');
      expect(replyPreviewLabel(text, ko), 'Photo');
      expect(
        replyPreviewLabel(
          const ChatReplyReference(
            messageId: '3',
            senderId: 'a',
            content: 'Voice Call',
            messageType: 'call',
            callOutcome: ChatCallOutcome.cancelled,
          ),
          ko,
        ),
        '취소',
      );
    },
  );

  testWidgets(
    'real app follows device then switches immediately during onboarding',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.platformDispatcher.localesTestValue = [const Locale('ko', 'KR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        NaruApp(
          appConfig: AppConfig(apiBaseUri: Uri.parse('http://localhost:1')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        find.text('로그인'),
        findsOneWidget,
        reason:
            'Locales: ${tester.platformDispatcher.locales}; texts: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).toList()}',
      );
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'test');
      await tester.enterText(fields.at(1), '준 🌿');
      await tester.enterText(fields.at(2), 'password');
      await tester.enterText(fields.at(3), 'password');
      await tester.pump();
      await tester.tap(find.text('계속'));
      await tester.pumpAndSettle();
      expect(find.text('사용할 언어'), findsOneWidget);
      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();
      expect(find.text('Tu idioma'), findsOneWidget);
      expect(find.text('Empezar a chatear'), findsOneWidget);
      expect(find.text('사용할 언어'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final language in AppLanguage.values) {
    testWidgets('signup name input and validation use ${language.code}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        LocalizedTestApp(
          language: language.code,
          theme: AppTheme.light,
          home: AuthScreen(
            isSigningUp: true,
            onSubmit:
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
      await tester.pumpAndSettle();
      final s = stringsForLanguage(language.code);
      final name = find.byKey(const ValueKey('auth-display-name'));
      expect(find.text(s.displayName), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: name, matching: find.byType(TextField)),
            )
            .decoration!
            .hintText,
        s.displayNameHint,
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'test');
      await tester.enterText(name, 'x' * 101);
      await tester.enterText(fields.at(2), 'secret');
      await tester.enterText(fields.at(3), 'secret');
      await tester.pump();
      await tester.tap(find.text(s.continueAction));
      await tester.pumpAndSettle();
      expect(find.text(s.textLengthLimit(100)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('login validation uses ${language.code}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        LocalizedTestApp(
          language: language.code,
          theme: AppTheme.light,
          home: AuthScreen(
            onSubmit:
                ({
                  required username,
                  required password,
                  displayName,
                  passwordConfirmation,
                  preferredLanguage,
                }) async {
                  throw const AuthException('Invalid username or password');
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final s = stringsForLanguage(language.code);
      expect(find.text(s.username), findsWidgets);
      await tester.enterText(find.byType(TextFormField).at(0), 'test');
      await tester.enterText(find.byType(TextFormField).at(1), 'bad-password');
      await tester.pump();
      await tester.tap(find.text(s.logIn));
      await tester.pumpAndSettle();
      expect(find.text(s.invalidCredentials), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chat attachment labels fit and use ${language.code}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        LocalizedTestApp(
          language: language.code,
          theme: AppTheme.light,
          home: ChatConversationView(
            currentUserName: 'Me',
            otherParticipantName: 'Lia',

            initialMessages: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final s = stringsForLanguage(language.code);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('message-input')))
            .decoration!
            .hintText,
        s.enterMessage,
      );
      await tester.tap(find.byKey(const ValueKey('message-attachment')));
      await tester.pumpAndSettle();
      expect(find.text(s.photo), findsOneWidget);
      expect(find.text(s.voiceMemo), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('call controls fit and use ${language.code}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: language.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ChatVoiceCallScreen(
            participantName: 'Ana',
            participantProfileImageUrl: null,
            connected: false,
            elapsed: Duration.zero,
            muted: true,
            audioOutputRoute: ChatAudioOutputRoute.speaker,
            onReturnToChat: () {},
            onToggleMute: () {},
            onEndCall: () {},
            onChooseAudioOutput: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final s = stringsForLanguage(language.code);
      expect(find.text(s.voiceCall), findsOneWidget);
      expect(find.text(s.speaker), findsOneWidget);
      expect(find.text(s.unmute), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
