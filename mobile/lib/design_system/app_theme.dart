import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_control_style.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

final class AppTheme {
  AppTheme._();

  // 기본 dark 스타일은 Android 하단 바를 검게 칠하므로 흰 화면의 색을 함께 지정해요.
  static const SystemUiOverlayStyle lightSystemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static final ColorScheme _lightColorScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primaryMuted,
        onPrimaryContainer: AppColors.blue900,
        secondary: AppColors.blue600,
        onSecondary: AppColors.white,
        secondaryContainer: AppColors.blue50,
        onSecondaryContainer: AppColors.blue900,
        error: AppColors.error,
        onError: AppColors.white,
        errorContainer: AppColors.errorMuted,
        onErrorContainer: AppColors.red900,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerLowest: AppColors.white,
        surfaceContainerLow: AppColors.grey50,
        surfaceContainer: AppColors.grey100,
        surfaceContainerHigh: AppColors.grey100,
        surfaceContainerHighest: AppColors.grey200,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.divider,
        shadow: AppColors.black,
        scrim: AppColors.black,
        surfaceTint: Colors.transparent,
      );

  static final TextTheme _textTheme = TextTheme(
    displayLarge: AppTypography.display.copyWith(color: AppColors.textPrimary),
    displayMedium: AppTypography.heading.copyWith(color: AppColors.textPrimary),
    displaySmall: AppTypography.subheading.copyWith(
      color: AppColors.textPrimary,
    ),
    headlineLarge: AppTypography.heading.copyWith(color: AppColors.textPrimary),
    headlineMedium: AppTypography.subheading.copyWith(
      color: AppColors.textPrimary,
    ),
    headlineSmall: AppTypography.screenTitle.copyWith(
      color: AppColors.textPrimary,
    ),
    titleLarge: AppTypography.screenTitle.copyWith(
      color: AppColors.textPrimary,
    ),
    titleMedium: AppTypography.cardTitle.copyWith(color: AppColors.textPrimary),
    titleSmall: AppTypography.sectionTitle.copyWith(
      color: AppColors.textPrimary,
    ),
    bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
    bodyMedium: AppTypography.body.copyWith(color: AppColors.textPrimary),
    bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
    labelLarge: AppTypography.button.copyWith(color: AppColors.textPrimary),
    labelMedium: AppTypography.fieldLabel.copyWith(
      color: AppColors.textSecondary,
    ),
    labelSmall: AppTypography.caption.copyWith(color: AppColors.textSecondary),
  );

  static ThemeData get light {
    final ThemeData baseTheme = ThemeData.from(
      colorScheme: _lightColorScheme,
      textTheme: _textTheme.apply(fontFamily: AppTypography.fontFamily),
      useMaterial3: true,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.divider,
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.space20,
        titleTextStyle: AppTypography.screenTitle.copyWith(
          color: AppColors.textPrimary,
          fontWeight: AppTypography.bold,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actionsIconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: AppControlStyle.inputTheme,
      filledButtonTheme: FilledButtonThemeData(style: AppControlStyle.button()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppControlStyle.button(secondary: true),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
            vertical: AppSpacing.space8,
          ),
          textStyle: AppControlStyle.buttonText,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadius12,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadius16,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.grey900,
        contentTextStyle: AppTypography.typography6.copyWith(
          color: AppColors.white,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadius12,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.blue100,
        selectionHandleColor: AppColors.primary,
      ),
    );
  }
}
