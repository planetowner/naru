import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_strings.dart';

String formatChatDate(DateTime date, {AppLocalizations? strings}) {
  final l10n = strings ?? stringsForLanguage('en');
  return DateFormat(l10n.datePattern, l10n.localeName).format(date.toLocal());
}

String formatChatScrollDate(DateTime date, {AppLocalizations? strings}) {
  final l10n = strings ?? stringsForLanguage('en');
  return DateFormat.MEd(l10n.localeName).format(date.toLocal());
}

String chatMonthName(int month, {AppLocalizations? strings}) =>
    (strings ?? stringsForLanguage('en')).calendarMonths.split(',')[month - 1];

String formatChatMonth(DateTime date, AppLocalizations strings) =>
    '${strings.calendarYear(date.year)} ${chatMonthName(date.month, strings: strings)}';

// 메시지와 미디어는 같은 언어와 기기의 24시간제 설정을 따라요.
String formatChatTime(DateTime date, BuildContext context) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(date.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

String formatMediaTimestamp(DateTime date, BuildContext context) =>
    context.l10n.mediaTimestamp(
      DateFormat.yMMMd(context.l10n.localeName).format(date.toLocal()),
      formatChatTime(date, context),
    );
