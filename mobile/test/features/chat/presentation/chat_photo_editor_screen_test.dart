import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/design_system/components/app_media_viewer_chrome.dart';
import 'package:naru/features/chat/presentation/chat_photo_editor_screen.dart';

Widget _buildTopBar({
  required int currentIndex,
  int photoCount = 3,
  bool visible = true,
}) {
  const double topPadding = 59;

  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          ChatPhotoEditorTopBar(
            visible: visible,
            height: AppMediaViewerChrome.topBarHeight(topPadding),
            topPadding: topPadding,
            currentIndex: currentIndex,
            photoCount: photoCount,
            sending: false,
            onBackPressed: () {},
            onSendPressed: () {},
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'editor top bar matches the viewer chrome and reference spacing',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(_buildTopBar(currentIndex: 0));

      final Finder topBar = find.byKey(
        const ValueKey<String>('photo-editor-top-bar'),
      );
      final Finder back = find.byKey(
        const ValueKey<String>('photo-editor-back'),
      );
      final Finder counter = find.byKey(
        const ValueKey<String>('photo-editor-counter'),
      );
      final Finder send = find.byKey(
        const ValueKey<String>('photo-editor-send'),
      );

      expect(tester.getSize(topBar), const Size(393, 126));
      expect(tester.getRect(back), const Rect.fromLTWH(16, 59, 44, 44));
      expect(tester.getTopLeft(counter).dx, 71);
      expect(tester.getRect(send).right, 377);
      expect(tester.getSize(send).height, 44);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('3 Send'), findsOneWidget);

      final Text counterText = tester.widget<Text>(counter);
      final Text sendText = tester.widget<Text>(
        find.byKey(const ValueKey<String>('photo-editor-send-label')),
      );

      expect(counterText.style?.fontSize, 18);
      expect(counterText.style?.fontWeight, FontWeight.w600);
      expect(sendText.style?.fontSize, 16);
      expect(sendText.style?.fontWeight, FontWeight.w400);

      final List<InlineSpan> sendParts =
          (sendText.textSpan! as TextSpan).children!;
      expect((sendParts.first as TextSpan).style?.fontWeight, isNull);
      expect((sendParts.last as TextSpan).style?.fontWeight, isNull);
    },
  );

  testWidgets('editor counter advances from the first selected photo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTopBar(currentIndex: 0));

    expect(find.text('1 / 3'), findsOneWidget);

    await tester.pumpWidget(_buildTopBar(currentIndex: 1));

    expect(find.text('2 / 3'), findsOneWidget);

    await tester.pumpWidget(_buildTopBar(currentIndex: 2));

    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('editor top controls use the viewer toggle transition', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTopBar(currentIndex: 0));

    await tester.pumpWidget(_buildTopBar(currentIndex: 0, visible: false));

    final AnimatedSlide hiddenSlide = tester.widget<AnimatedSlide>(
      find.byKey(const ValueKey<String>('photo-editor-top-bar-slide')),
    );
    final AnimatedOpacity hiddenOpacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey<String>('photo-editor-top-bar-opacity')),
    );
    final IgnorePointer hiddenPointer = tester.widget<IgnorePointer>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('photo-editor-top-bar-slide')),
        matching: find.byType(IgnorePointer),
      ),
    );

    expect(hiddenSlide.duration, const Duration(milliseconds: 200));
    expect(hiddenSlide.curve, Curves.linear);
    expect(hiddenSlide.offset, const Offset(0, -1));
    expect(hiddenOpacity.duration, const Duration(milliseconds: 200));
    expect(hiddenOpacity.opacity, 0);
    expect(hiddenPointer.ignoring, isTrue);

    await tester.pumpWidget(_buildTopBar(currentIndex: 0));

    final AnimatedSlide visibleSlide = tester.widget<AnimatedSlide>(
      find.byKey(const ValueKey<String>('photo-editor-top-bar-slide')),
    );
    final AnimatedOpacity visibleOpacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey<String>('photo-editor-top-bar-opacity')),
    );

    expect(visibleSlide.curve, Curves.easeOutCubic);
    expect(visibleSlide.offset, Offset.zero);
    expect(visibleOpacity.opacity, 1);
  });
}
