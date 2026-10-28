import 'package:flutter/material.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/app_typography.dart';

abstract final class ChatComposerStyle {
  // 입력창과 복사 안내의 좌우 정렬, 키보드·첨부 패널 위 여백을 함께 유지해요.
  static const double horizontalPadding = 10;

  static const double raisedBottomPadding = 10;

  // 키보드가 홈 인디케이터 아래로 내려가도 입력창과 검색 바가 다시 튀지 않게 해요.
  static double keyboardBottomPadding({
    required double keyboardHeight,
    required double systemBottomPadding,
  }) => (keyboardHeight - systemBottomPadding)
      .clamp(0, raisedBottomPadding)
      .toDouble();

  // 기본 입력과 답장·수정 입력은 기존 크기와 여백이 달라 각각 유지해요.
  static const double defaultMinimumHeight = 48;

  static const double defaultActionDimension = 32;

  static final TextStyle defaultInput = AppTypography.typography6.copyWith(
    color: AppColors.textPrimary,
    fontWeight: AppTypography.regular,
  );

  static const int contextSummaryMaxLines = 1;

  static const double contextActionDimension = 42;

  static final TextStyle contextInput = AppTypography.subTypography10.copyWith(
    color: AppColors.textPrimary,
    fontWeight: AppTypography.regular,
  );

  static const double neutralIconSize = 20;
}
