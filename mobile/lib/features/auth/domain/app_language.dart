import 'package:flutter/widgets.dart';

enum AppLanguage {
  korean('ko', '한국어'),
  japanese('ja', '日本語'),
  chinese('zh-CN', '中文（简体）'),
  english('en', 'English'),
  spanish('es', 'Español'),
  french('fr', 'Français'),
  german('de', 'Deutsch'),
  italian('it', 'Italiano');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  Locale get locale => Locale(code.split('-').first);

  static AppLanguage fromLocale(Locale locale) => values.firstWhere(
    (language) => language.locale.languageCode == locale.languageCode,
    orElse: () => english,
  );

  static AppLanguage fromCode(String code) =>
      fromLocale(Locale(code.replaceAll('_', '-').split('-').first));

  static Locale resolveLocales(
    List<Locale>? deviceLocales,
    Iterable<Locale> _,
  ) {
    return fromLocale(deviceLocales?.firstOrNull ?? const Locale('en')).locale;
  }
}
