import 'package:flutter/material.dart';

import '../app_control_style.dart';

final class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppControlStyle.height,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: AppControlStyle.button(
        secondary: true,
      ).copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.zero)),
      icon: Icon(icon, size: 24),
    ),
  );
}
