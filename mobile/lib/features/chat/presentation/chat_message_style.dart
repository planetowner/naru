import 'package:flutter/material.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/app_typography.dart';

abstract final class ChatMessageStyle {
  // 말풍선과 미디어의 기존 모양을 유지해요. 가까운 공통 반경으로 바꾸지 않아요.
  static const double bubbleRadius = 17;

  static const double tailCornerRadius = 13;

  static const BorderRadius bubbleBorderRadius = BorderRadius.all(
    Radius.circular(bubbleRadius),
  );

  static const BorderRadius mediaBorderRadius = BorderRadius.all(
    Radius.circular(14),
  );

  static const double horizontalPadding = 11;

  static const double groupedMessageGap = 5;

  static const double timestampGap = 6;

  // 본문·링크·사진·영상은 같은 화면 너비 비율을 써요. 카드별 최대 크기는 따로 유지해요.
  static const double maximumWidthRatio = 0.68;

  static const double tailHorizontalOffset = -7;

  // 답장과 음성 카드의 구분선은 실제 배치와 크기 측정에서 같은 규격을 사용해요.
  static const double contentDividerGap = 7;

  static const double contentDividerThickness = 1;

  static const Duration translationFadeDuration = Duration(milliseconds: 160);

  // 본문과 링크 메시지는 방향에 따라 글자색만 달라져요.
  // 흰 배경인 통화 카드는 발신 여부와 관계없이 기본 글자색을 사용해요.
  static TextStyle body({bool isOutgoing = false}) {
    return AppTypography.subTypography10.copyWith(
      color: isOutgoing ? AppColors.textOnPrimary : AppColors.textPrimary,
      fontWeight: AppTypography.regular,
    );
  }

  static TextStyle replyTitle({required bool isOutgoing}) {
    return body(
      isOutgoing: isOutgoing,
    ).copyWith(fontWeight: AppTypography.bold);
  }

  static TextStyle replyPreview({required bool isOutgoing}) {
    return body(isOutgoing: isOutgoing).copyWith(
      color: isOutgoing ? AppColors.white.withAlpha(220) : AppColors.grey700,
    );
  }

  static Color contentDividerColor({required bool isOutgoing}) {
    return isOutgoing ? AppColors.white.withAlpha(56) : AppColors.grey200;
  }

  static TextStyle editedLabel({required bool isOutgoing}) {
    return AppTypography.typography7.copyWith(
      color: isOutgoing ? AppColors.white.withAlpha(190) : AppColors.grey600,
      fontWeight: AppTypography.regular,
    );
  }

  // 번역 안내는 같은 글자 규격을 쓰고, 상태에 따라 색상만 달라져요.
  static TextStyle translationTextStyle(Color color) {
    return AppTypography.subTypography12.copyWith(
      color: color,
      fontWeight: AppTypography.regular,
    );
  }

  static final TextStyle translationRetry = translationTextStyle(
    AppColors.blue500,
  );

  static Color searchHighlightColor({
    required bool isOutgoing,
    required bool isActiveResult,
  }) {
    if (isOutgoing) {
      return isActiveResult ? AppColors.blue900 : AppColors.white.withAlpha(76);
    }

    return isActiveResult ? AppColors.blue200 : AppColors.primary.withAlpha(54);
  }
}
