import 'package:flutter/widgets.dart';

import '../../features/auth/domain/app_language.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

// 화면과 다이얼로그는 같은 Locale을 구독하고, 날짜·알림도 같은 번역을 사용해요.
extension AppStringsContext on BuildContext {
  AppLocalizations get l10n => stringsForLocale(Localizations.localeOf(this));
}

AppLocalizations stringsForLocale(Locale locale) =>
    lookupAppLocalizations(AppLanguage.fromLocale(locale).locale);

AppLocalizations stringsForLanguage(String languageCode) =>
    lookupAppLocalizations(AppLanguage.fromCode(languageCode).locale);
