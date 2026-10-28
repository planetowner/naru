import 'package:flutter/material.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/app_radius.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/app_profile_image.dart';
import '../../auth/domain/app_user.dart';

// 목록과 검색 결과는 사진·이름·아이디 정렬을 공유하고 오른쪽 동작만 바꿔요.
final class UserTile extends StatelessWidget {
  const UserTile({
    required this.user,
    this.onTap,
    this.trailing,
    this.unreadCount = 0,
    super.key,
  });
  static const double horizontalPadding = AppSpacing.space20;
  static const double avatarSize = 48;
  static const double titleGap = AppSpacing.space16;
  static const double textStartInset =
      horizontalPadding + avatarSize + titleGap;

  final AppUser user;
  final VoidCallback? onTap;
  final Widget? trailing;
  final int unreadCount;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 6,
        ),
        child: Row(
          children: [
            _UserAvatar(
              imageUrl: user.profileImageUrl,
              unreadCount: unreadCount,
            ),
            const SizedBox(width: titleGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: titleGap),
              trailing!,
            ],
          ],
        ),
      ),
    ),
  );
}

final class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.imageUrl, required this.unreadCount});

  final String? imageUrl;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: UserTile.avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AppProfileImage(
              imageUrl: imageUrl,
              size: UserTile.avatarSize,
              borderRadius: AppRadius.radius16,
              iconSize: 30,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: _UnreadBadge(count: unreadCount),
            ),
        ],
      ),
    );
  }
}

final class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final String label = count > 99 ? '99+' : count.toString();

    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.red500,
        borderRadius: AppRadius.borderRadiusFull,
      ),
      child: Text(
        label,
        // 작은 배지 안에 숫자를 맞추기 위해 줄 높이는 1로 유지해요.
        style: AppTypography.subTypography13.copyWith(
          color: AppColors.white,
          fontWeight: AppTypography.bold,
          height: 1,
        ),
      ),
    );
  }
}
