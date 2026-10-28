import '../../../core/l10n/app_strings.dart';

String formatReadReceipt({
  required DateTime readAt,
  required DateTime now,
  AppLocalizations? strings,
}) {
  final l10n = strings ?? stringsForLanguage('en');
  final difference = now.toLocal().difference(readAt.toLocal());
  final elapsed = difference.isNegative ? Duration.zero : difference;
  if (elapsed < const Duration(minutes: 1)) return l10n.seenNow;
  if (elapsed < const Duration(hours: 1)) {
    return l10n.seenMinutes(elapsed.inMinutes);
  }
  if (elapsed < const Duration(days: 1)) return l10n.seenHours(elapsed.inHours);
  if (elapsed < const Duration(days: 2)) return l10n.seenYesterday;
  if (elapsed < const Duration(days: 7)) return l10n.seenDays(elapsed.inDays);
  if (elapsed < const Duration(days: 14)) return l10n.seenLastWeek;
  // 30일이 지나도 같은 주 단위 규칙을 유지해요.
  return l10n.seenWeeks(elapsed.inDays ~/ 7);
}
