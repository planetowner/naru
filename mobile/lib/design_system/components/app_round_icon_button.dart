import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'app_media_viewer_chrome.dart';

/// 채팅 상단과 통화에서 같은 원형 터치 영역과 버튼 표면을 사용해요.
final class AppRoundIconButton extends StatelessWidget {
  const AppRoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.backgroundColor = AppColors.surface,
    this.foregroundColor = AppColors.textPrimary,
    this.borderColor = AppColors.border,
    this.isLoading = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null && !isLoading,
    label: tooltip,
    child: Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: AppMediaViewerChromeButton(
        onPressed: isLoading ? null : onPressed,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        child: isLoading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : Icon(icon, size: 24, color: foregroundColor),
      ),
    ),
  );
}
