import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';

import '../app_colors.dart';
import '../app_icons.dart';
import '../app_spacing.dart';
import '../app_typography.dart';
import 'app_media_viewer_chrome.dart';
import 'app_round_icon_button.dart';

final class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    required this.title,
    required this.backTooltip,
    required this.onBack,
    this.backIcon = AppIcons.back,
    this.trailing,
    super.key,
  });

  static const double height =
      AppMediaViewerChrome.buttonDimension + AppSpacing.space12;

  final String title;
  final String? backTooltip;
  final VoidCallback? onBack;
  final IconData backIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        0,
        AppSpacing.space16,
        AppSpacing.space12,
      ),
      child: Row(
        children: [
          AppRoundIconButton(
            icon: backIcon,
            tooltip: backTooltip ?? context.l10n.back,
            onPressed: onBack,
          ),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.navigationTitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space12),
          // 오른쪽 동작이 없어도 같은 폭을 남겨 제목을 중앙에 맞춰요.
          SizedBox(
            width: AppMediaViewerChrome.buttonDimension,
            child: trailing,
          ),
        ],
      ),
    ),
  );
}
