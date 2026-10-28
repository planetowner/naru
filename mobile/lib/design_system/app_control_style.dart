import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Yeoul의 버튼·기본 입력 규격을 한곳에서 관리해요.
final class AppControlStyle {
  AppControlStyle._();

  static const double height = 46;
  static const double buttonRadius = 10;
  static const double inputRadius = 8;
  static const double horizontalInset = 14;
  static const Color borderColor = Color(0xFFD8DEE5);
  static const TextStyle inputText = AppTypography.body;
  static const TextStyle buttonText = AppTypography.button;
  static final TextStyle inputLabel = AppTypography.fieldLabel.copyWith(
    color: AppColors.textSecondary,
  );
  static const OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(inputRadius)),
    borderSide: BorderSide(color: borderColor),
  );
  static final InputDecorationThemeData inputTheme = InputDecorationThemeData(
    filled: true,
    fillColor: AppColors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: horizontalInset,
      vertical: 12,
    ),
    hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
    border: inputBorder,
    enabledBorder: inputBorder,
    disabledBorder: inputBorder,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(inputRadius)),
      borderSide: BorderSide(color: AppColors.primary),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(inputRadius)),
      borderSide: BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(inputRadius)),
      borderSide: BorderSide(color: AppColors.error),
    ),
    prefixIconConstraints: const BoxConstraints(
      minWidth: height,
      minHeight: height,
    ),
    suffixIconConstraints: const BoxConstraints(
      minWidth: height,
      minHeight: height,
    ),
    prefixIconColor: AppColors.textSecondary,
    suffixIconColor: AppColors.textSecondary,
  );

  static ButtonStyle button({bool secondary = false}) => FilledButton.styleFrom(
    minimumSize: const Size(0, height),
    padding: const EdgeInsets.symmetric(horizontal: horizontalInset),
    backgroundColor: secondary ? AppColors.white : AppColors.primary,
    foregroundColor: secondary ? AppColors.textPrimary : AppColors.white,
    disabledBackgroundColor: AppColors.grey100,
    disabledForegroundColor: AppColors.textDisabled,
    elevation: 0,
    textStyle: buttonText,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    ),
    side: secondary ? const BorderSide(color: borderColor) : BorderSide.none,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
