import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/features/auth/domain/app_language.dart';
import 'package:naru/features/chat/presentation/chat_date_formatter.dart';
import '../../support/localized_test_app.dart';

void main() {
  testWidgets(
    'message and media times share locale and device time preference',
    (tester) async {
      final date = DateTime(2026, 10, 28, 19, 5);
      for (final language in AppLanguage.values) {
        for (final use24Hours in [false, true]) {
          await tester.pumpWidget(
            LocalizedTestApp(
              language: language.code,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(alwaysUse24HourFormat: use24Hours),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Column(
                  children: [
                    Text(
                      formatChatTime(date, context),
                      key: const ValueKey('chat-time'),
                    ),
                    Text(
                      formatMediaTimestamp(date, context),
                      key: const ValueKey('media-time'),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final time = tester
              .widget<Text>(find.byKey(const ValueKey('chat-time')))
              .data!;
          final media = tester
              .widget<Text>(find.byKey(const ValueKey('media-time')))
              .data!;
          expect(media, contains(time));
          expect(media, contains('2026'));
          if (use24Hours) {
            expect(time, '19:05');
          } else if (language == AppLanguage.english) {
            expect(time, '7:05 PM');
          } else if (language == AppLanguage.korean) {
            expect(time, '오후 7:05');
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  test('formats the date in English weekday month day year order', () {
    expect(formatChatDate(DateTime(2026, 6, 30)), 'Tuesday, June 30, 2026');
  });

  test('formats a single-digit day without a leading zero', () {
    expect(formatChatDate(DateTime(2026, 7, 4)), 'Saturday, July 4, 2026');
  });

  test('formats the compact date used beside the chat scrollbar', () {
    expect(formatChatScrollDate(DateTime(2026, 7, 28)), 'Tue, 7/28');
  });
}
