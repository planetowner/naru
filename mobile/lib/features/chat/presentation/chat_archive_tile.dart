import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/app_colors.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/app_media_viewer_chrome.dart';
import '../../account/presentation/user_tile.dart';

/// 기존 목록 행을 밀어 버튼만 보여 줘요. 보관은 버튼을 눌렀을 때 실행해요.
final class ChatArchiveTile extends StatefulWidget {
  const ChatArchiveTile({
    required this.child,
    required this.onArchive,
    super.key,
  });

  final Widget child;
  final VoidCallback onArchive;

  @override
  State<ChatArchiveTile> createState() => _ChatArchiveTileState();
}

final class _ChatArchiveTileState extends State<ChatArchiveTile>
    with SingleTickerProviderStateMixin {
  static const double _buttonSize = UserTile.avatarSize + AppSpacing.space8;
  static const double _revealWidth =
      _buttonSize + UserTile.horizontalPadding + AppSpacing.space8;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _settle(bool open) {
    _controller.animateTo(open ? 1 : 0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _controller.stop(),
      onHorizontalDragUpdate: (details) {
        _controller.value -= details.delta.dx / _revealWidth;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        _settle(velocity.abs() > 300 ? velocity < 0 : _controller.value >= 0.5);
      },
      onHorizontalDragCancel: () => _settle(false),
      onTap: _controller.value > 0 ? () => _settle(false) : null,
      child: ClipRect(
        child: Stack(
          children: [
            if (_controller.value > 0)
              Positioned(
                right: UserTile.horizontalPadding,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Semantics(
                    button: true,
                    child: AppMediaViewerChromeButton(
                      dimension: _buttonSize,
                      backgroundColor: AppColors.grey500,
                      borderColor: Colors.transparent,
                      onPressed: widget.onArchive,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.space8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            context.l10n.archiveChat,
                            style: AppTypography.body.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(-_revealWidth * _controller.value, 0),
              child: AbsorbPointer(
                absorbing: _controller.value > 0,
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
    child: Material(color: AppColors.surface, child: widget.child),
  );
}
