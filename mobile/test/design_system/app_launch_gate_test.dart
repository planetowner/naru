import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/design_system/components/app_launch_screen.dart';

Widget _buildLaunchGate(ValueNotifier<bool> ready) {
  return MaterialApp(
    home: ValueListenableBuilder<bool>(
      valueListenable: ready,
      builder: (BuildContext context, bool isReady, Widget? child) {
        return AppLaunchGate(
          isReady: isReady,
          child: const Scaffold(body: Text('Ready screen')),
        );
      },
    ),
  );
}

void main() {
  testWidgets('fast startup still shows the logo before fading to content', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<bool> ready = ValueNotifier<bool>(true);
    addTearDown(ready.dispose);
    await tester.pumpWidget(_buildLaunchGate(ready));

    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.text('Ready screen'), findsNothing);
    expect(find.byType(AppLaunchScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 125));
    expect(find.byType(AppLaunchScreen), findsOneWidget);
    expect(find.text('Ready screen'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 125));
    // Flutter는 종료 시간을 지난 다음 프레임에 애니메이션 완료를 알려줘요.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(AppLaunchScreen), findsNothing);
    expect(find.text('Ready screen'), findsOneWidget);
  });

  testWidgets(
    'slow startup waits for readiness without another minimum delay',
    (WidgetTester tester) async {
      final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
      addTearDown(ready.dispose);
      await tester.pumpWidget(_buildLaunchGate(ready));

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Ready screen'), findsNothing);
      expect(find.byType(AppLaunchScreen), findsOneWidget);

      ready.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(AppLaunchScreen), findsNothing);
      expect(find.text('Ready screen'), findsOneWidget);
    },
  );

  testWidgets('later loading changes do not replay the launch screen', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<bool> ready = ValueNotifier<bool>(true);
    addTearDown(ready.dispose);
    await tester.pumpWidget(_buildLaunchGate(ready));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 16));

    ready.value = false;
    await tester.pump();
    expect(find.byType(AppLaunchScreen), findsNothing);
    expect(find.text('Ready screen'), findsOneWidget);

    ready.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(AppLaunchScreen), findsNothing);
  });
}
