import 'package:flutter_test/flutter_test.dart';

Future<void> pumpRealAsyncUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String failureReason,
}) async {
  final Stopwatch timeout = Stopwatch()..start();

  await tester.runAsync(() async {
    while (!condition() && timeout.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await tester.pump();
    }
  });
  await tester.pump();

  expect(condition(), isTrue, reason: failureReason);
}
