import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_typography.dart';

final class AppTextLink extends StatelessWidget {
  const AppTextLink({required this.label, required this.onPressed, super.key});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTypography.button,
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(label),
  );
}
