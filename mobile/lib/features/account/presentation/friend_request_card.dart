import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/app_radius.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/components.dart';
import '../domain/friend_request.dart';

final class FriendRequestCard extends StatefulWidget {
  const FriendRequestCard({
    required this.request,
    required this.onRespond,
    super.key,
  });

  final FriendRequest request;
  final Future<void> Function(FriendRequestDecision) onRespond;

  @override
  State<FriendRequestCard> createState() => _FriendRequestCardState();
}

final class _FriendRequestCardState extends State<FriendRequestCard> {
  FriendRequestDecision? _submitting;
  bool _failed = false;

  Future<void> _respond(FriendRequestDecision decision) async {
    if (_submitting != null) return;
    setState(() {
      _submitting = decision;
      _failed = false;
    });
    try {
      await widget.onRespond(decision);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _submitting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sender = widget.request.sender;
    final strings = context.l10n;
    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.space24),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadius24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 342),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.friendRequest,
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.space24),
                AppProfileImage.large(imageUrl: sender.profileImageUrl),
                const SizedBox(height: AppSpacing.space16),
                Text(
                  sender.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle,
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  '@${sender.username}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space24),
                if (_failed) ...[
                  Text(
                    strings.requestFailed,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.space16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: strings.decline,
                        secondary: true,
                        isLoading: _submitting == FriendRequestDecision.decline,
                        onPressed: _submitting == null
                            ? () => _respond(FriendRequestDecision.decline)
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    Expanded(
                      child: AppButton(
                        label: strings.accept,
                        isLoading: _submitting == FriendRequestDecision.accept,
                        onPressed: _submitting == null
                            ? () => _respond(FriendRequestDecision.accept)
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
