import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/design_system/app_colors.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/design_system/components/app_profile_image.dart';
import 'package:naru/design_system/components/app_round_icon_button.dart';
import 'package:naru/features/chat/presentation/chat_conversation_view.dart';
import 'package:naru/design_system/components/app_navigation_bar.dart';
import 'package:naru/features/chat/presentation/chat_voice_call_screen.dart';

import '../../../support/load_app_fonts.dart';

Widget _shell(Widget child, {required Size size, required EdgeInsets insets}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, padding: insets, viewPadding: insets),
        child: child,
      ),
    );

AppRoundIconButton _button(WidgetTester tester, String tooltip) =>
    tester.widget<AppRoundIconButton>(
      find.byWidgetPredicate(
        (widget) => widget is AppRoundIconButton && widget.tooltip == tooltip,
      ),
    );

Future<void> _openCall(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Call'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Voice Call'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets('call states preserve positions and actions at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const insets = EdgeInsets.only(top: 44, bottom: 34);
      final actions = <String>[];
      Rect? profileRect;

      for (final state in [(false, false), (true, false), (true, true)]) {
        await tester.pumpWidget(
          _shell(
            ChatVoiceCallScreen(
              participantName: 'Lia',
              participantProfileImageUrl: null,
              connected: state.$1,
              elapsed: const Duration(minutes: 3, seconds: 24),
              muted: state.$2,
              audioOutputRoute: ChatAudioOutputRoute.speaker,
              onReturnToChat: () => actions.add('back'),
              onToggleMute: () => actions.add('mute'),
              onEndCall: () => actions.add('end'),
              onChooseAudioOutput: () => actions.add('output'),
            ),
            size: size,
            insets: insets,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(state.$1 ? '03:24' : 'Connecting…'), findsOneWidget);
        expect(
          find.text('Your mic is off'),
          state.$2 ? findsOneWidget : findsNothing,
        );

        final rect = tester.getRect(find.byType(AppProfileImage));
        profileRect ??= rect;
        expect(rect, profileRect);
        expect(rect.size, const Size(112, 112));
        final title = tester.widget<Text>(find.text('Voice Call'));
        expect(title.style!.fontSize, 18);
        expect(title.style!.height, 1.5);
        expect(title.style!.fontWeight, FontWeight.w700);

        final muteLabel = state.$2 ? 'Unmute' : 'Mute';
        final mute = _button(tester, muteLabel);
        expect(mute.foregroundColor, AppColors.textPrimary);
        expect(
          mute.backgroundColor,
          state.$2 ? AppColors.grey100 : AppColors.surface,
        );
        expect(
          _button(tester, 'Speaker').foregroundColor,
          AppColors.textPrimary,
        );
        expect(_button(tester, 'End call').backgroundColor, AppColors.error);

        final centers = <Offset>[];
        for (final label in [muteLabel, 'End call', 'Speaker']) {
          final target = find.byTooltip(label);
          expect(tester.getSize(target), const Size(44, 44));
          expect(
            tester.getRect(target).bottom,
            lessThan(size.height - insets.bottom),
          );
          centers.add(tester.getCenter(target));
          await tester.tap(target);
        }
        expect(centers[0].dy, centers[1].dy);
        expect(centers[1].dy, centers[2].dy);
        expect(centers[1].dx, closeTo(size.width / 2, 0.001));
        expect(centers[0].dx, lessThan(centers[1].dx));
        expect(centers[2].dx, greaterThan(centers[1].dx));
        await tester.tap(find.byTooltip('Back to chat'));
      }
      expect(
        actions,
        List.generate(
          3,
          (_) => ['mute', 'end', 'output', 'back'],
        ).expand((x) => x),
      );
    });
  }

  testWidgets('search and call headers match the participant name style', (
    tester,
  ) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shell(
        const ChatConversationView(
          currentUserName: 'Me',

          initialMessages: [],
          otherParticipantName: 'Lia',
        ),
        size: size,
        insets: const EdgeInsets.only(top: 44, bottom: 34),
      ),
    );
    await tester.pumpAndSettle();
    final participant = tester.widget<Text>(
      find.byKey(const ValueKey('chat-participant-name')),
    );
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    final search = tester.widget<Text>(find.text('Search'));
    expect(search.style, participant.style);
    expect(tester.getSize(find.byType(AppNavigationBar)), const Size(390, 56));
    expect(tester.getSize(find.byTooltip('Close search')), const Size(44, 44));
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    await _openCall(tester);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byType(AppNavigationBar),
              matching: find.text('Voice Call'),
            ),
          )
          .style,
      participant.style,
    );
    await tester.tap(find.byTooltip('End call'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatVoiceCallScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mute, route selection, return to chat and end retain call state',
    (tester) async {
      const size = Size(390, 844);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _shell(
          const ChatConversationView(
            currentUserName: 'Me',

            initialMessages: [],
            otherParticipantName: 'Lia',
          ),
          size: size,
          insets: const EdgeInsets.only(top: 44, bottom: 34),
        ),
      );
      await tester.pumpAndSettle();
      await _openCall(tester);
      await tester.tap(find.byTooltip('Mute'));
      await tester.pumpAndSettle();
      expect(find.text('Your mic is off'), findsOneWidget);
      expect(find.byTooltip('Unmute'), findsOneWidget);

      await tester.tap(find.byTooltip('Speaker'));
      await tester.pumpAndSettle();
      expect(find.text('Audio output'), findsOneWidget);
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      expect(_button(tester, 'Phone').backgroundColor, AppColors.surface);

      await tester.tap(find.byTooltip('Phone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bluetooth Headset'));
      await tester.pumpAndSettle();
      expect(
        _button(tester, 'Bluetooth Headset').foregroundColor,
        AppColors.textPrimary,
      );

      await tester.tap(find.byTooltip('Back to chat'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatVoiceCallScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('active-voice-call-banner')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unmute'), findsOneWidget);
      expect(find.byTooltip('Bluetooth Headset'), findsOneWidget);
      await tester.tap(find.byTooltip('Unmute'));
      await tester.pumpAndSettle();
      expect(find.text('Your mic is off'), findsNothing);
      await tester.tap(find.byTooltip('End call'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('active-voice-call-banner')),
        findsNothing,
      );
      expect(find.byType(ChatVoiceCallScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
