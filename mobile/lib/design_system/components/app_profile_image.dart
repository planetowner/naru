import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_icons.dart';

final class AppProfileImage extends StatelessWidget {
  const AppProfileImage({
    required this.imageUrl,
    required this.size,
    required this.borderRadius,
    required this.iconSize,
    this.iconColor = AppColors.white,
    this.image,
    super.key,
  });

  const AppProfileImage.large({
    required this.imageUrl,
    this.image,
    this.iconColor = AppColors.white,
    super.key,
  }) : size = 112,
       borderRadius = 32,
       iconSize = 64;

  final String? imageUrl;
  final double size;
  final double borderRadius;
  final double iconSize;
  final Color iconColor;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final String? resolvedImageUrl = imageUrl?.trim();
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Widget fallback = DecoratedBox(
      decoration: BoxDecoration(color: AppColors.blue100, borderRadius: radius),
      child: Icon(AppIcons.person, color: iconColor, size: iconSize),
    );

    final ImageProvider? provider =
        image ??
        (resolvedImageUrl == null || resolvedImageUrl.isEmpty
            ? null
            : NetworkImage(resolvedImageUrl));
    return SizedBox.square(
      dimension: size,
      child: provider == null
          ? fallback
          : ClipRRect(
              borderRadius: radius,
              child: Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
    );
  }
}
