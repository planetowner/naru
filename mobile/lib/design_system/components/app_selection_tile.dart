import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_icons.dart';
import '../app_radius.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

// 오디오 출력과 언어 선택은 같은 행에서 값과 선택 결과만 바꿔요.
final class AppSelectionTile extends StatelessWidget {
  const AppSelectionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: Material(
      color: selected ? AppColors.grey100 : AppColors.surface,
      borderRadius: AppRadius.borderRadius16,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 24,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.space12),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.space12),
                  const Icon(
                    AppIcons.check,
                    size: 24,
                    color: AppColors.textPrimary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
