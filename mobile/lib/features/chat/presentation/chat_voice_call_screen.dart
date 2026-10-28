import '../../../core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/app_icons.dart';
import '../../../design_system/app_radius.dart';
import '../../../design_system/app_spacing.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/app_profile_image.dart';
import '../../../design_system/components/app_selection_tile.dart';
import '../../../design_system/components/app_round_icon_button.dart';
import 'chat_action_sheet_style.dart';
import 'chat_duration_formatter.dart';
import '../../../design_system/components/app_navigation_bar.dart';

enum ChatAudioOutputRoute {
  phone,
  speaker,
  bluetooth;

  String label(BuildContext context) => switch (this) {
    phone => context.l10n.phone,
    speaker => context.l10n.speaker,
    bluetooth => context.l10n.bluetoothHeadset,
  };

  IconData get icon => switch (this) {
    phone => AppIcons.phoneInTalk,
    speaker => AppIcons.volumeUp,
    bluetooth => AppIcons.headphones,
  };
}

final class ChatVoiceCallScreen extends StatelessWidget {
  const ChatVoiceCallScreen({
    required this.participantName,
    required this.participantProfileImageUrl,
    required this.connected,
    required this.elapsed,
    required this.muted,
    required this.audioOutputRoute,
    required this.onReturnToChat,
    required this.onToggleMute,
    required this.onEndCall,
    required this.onChooseAudioOutput,
    super.key,
  });

  final String participantName;
  final String? participantProfileImageUrl;
  final bool connected;
  final Duration elapsed;
  final bool muted;
  final ChatAudioOutputRoute audioOutputRoute;
  final VoidCallback onReturnToChat;
  final VoidCallback onToggleMute;
  final VoidCallback onEndCall;
  final VoidCallback onChooseAudioOutput;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey<String>('voice-call-screen'),
    color: AppColors.background,
    child: SafeArea(
      child: Column(
        children: [
          AppNavigationBar(
            title: context.l10n.voiceCall,
            backTooltip: context.l10n.backToChat,
            onBack: onReturnToChat,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppProfileImage.large(
                      imageUrl: participantProfileImageUrl,
                      iconColor: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    Text(
                      participantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.heading.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    Text(
                      connected
                          ? formatChatCallDuration(elapsed)
                          : context.l10n.connecting,
                      style: AppTypography.bodyLarge.copyWith(
                        color: connected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    // 음소거를 바꿔도 프로필과 이름의 위치가 움직이지 않게 해요.
                    SizedBox(
                      width: 160,
                      height: 32,
                      child: muted
                          ? DecoratedBox(
                              decoration: const BoxDecoration(
                                color: AppColors.grey100,
                                borderRadius: AppRadius.borderRadiusFull,
                              ),
                              child: Center(
                                child: Text(
                                  context.l10n.micOff,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space24,
              0,
              AppSpacing.space24,
              AppSpacing.space24,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CallControlButton(
                    label: muted ? context.l10n.unmute : context.l10n.mute,
                    icon: muted ? AppIcons.micOff : AppIcons.mic,
                    active: muted,
                    onPressed: onToggleMute,
                  ),
                ),
                const SizedBox(width: AppSpacing.space16),
                Expanded(
                  child: _CallControlButton(
                    label: context.l10n.endCall,
                    icon: AppIcons.callEnd,
                    destructive: true,
                    onPressed: onEndCall,
                  ),
                ),
                const SizedBox(width: AppSpacing.space16),
                Expanded(
                  child: _CallControlButton(
                    label: audioOutputRoute.label(context),
                    icon: audioOutputRoute.icon,
                    active: audioOutputRoute != ChatAudioOutputRoute.phone,
                    onPressed: onChooseAudioOutput,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

final class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppRoundIconButton(
        icon: icon,
        tooltip: label,
        onPressed: onPressed,
        backgroundColor: destructive
            ? AppColors.error
            : active
            ? AppColors.grey100
            : AppColors.surface,
        foregroundColor: destructive
            ? AppColors.textOnPrimary
            : AppColors.textPrimary,
        borderColor: destructive ? AppColors.error : AppColors.border,
      ),
      const SizedBox(height: AppSpacing.space8),
      Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.bodySmall.copyWith(
          color: destructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
    ],
  );
}

final class ChatAudioOutputSheet extends StatelessWidget {
  const ChatAudioOutputSheet({required this.selectedRoute, super.key});

  final ChatAudioOutputRoute selectedRoute;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: ChatActionSheetStyle.borderRadius,
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: Padding(
        // 출력 선택창은 승인한 통화 시안의 24px 여백을 쓰고 안전 영역은 한 번만 더해요.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space24,
          AppSpacing.space12,
          AppSpacing.space24,
          AppSpacing.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.grey300,
                borderRadius: AppRadius.borderRadiusFull,
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            Text(
              context.l10n.audioOutput,
              style: AppTypography.sectionTitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space24),
            for (final route in ChatAudioOutputRoute.values) ...[
              if (route != ChatAudioOutputRoute.values.first)
                const SizedBox(height: AppSpacing.space4),
              _AudioOutputOption(
                route: route,
                selected: route == selectedRoute,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

final class _AudioOutputOption extends StatelessWidget {
  const _AudioOutputOption({required this.route, required this.selected});

  final ChatAudioOutputRoute route;
  final bool selected;

  @override
  Widget build(BuildContext context) => AppSelectionTile(
    label: route.label(context),
    icon: route.icon,
    selected: selected,
    onTap: () => Navigator.of(context).pop(route),
  );
}
