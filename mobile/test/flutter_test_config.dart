import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // 단독 위젯 테스트에서도 앱의 LocalizationsDelegate와 같은 날짜 데이터를 준비해요.
  await initializeDateFormatting();
  await testMain();
}
