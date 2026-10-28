import 'package:flutter/material.dart';
import 'package:naru/core/l10n/app_strings.dart';
import 'package:naru/features/auth/domain/app_language.dart';

final class LocalizedTestApp extends StatelessWidget {
  const LocalizedTestApp({
    required this.home,
    this.language = 'en',
    this.theme,
    this.builder,
    super.key,
  });
  final Widget home;
  final String language;
  final ThemeData? theme;
  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: AppLanguage.fromCode(language).locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: theme,
    builder: builder,
    home: home,
  );
}
