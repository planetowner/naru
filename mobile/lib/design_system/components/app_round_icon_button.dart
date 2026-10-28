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
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: AppMediaViewerChromeButton(
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        child: Icon(icon, size: 24, color: foregroundColor),
      ),
    ),
  );
}
