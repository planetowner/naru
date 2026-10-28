import 'package:flutter/services.dart';

// 대체 글꼴 대신 앱에 포함된 실제 글꼴로 줄바꿈과 컨트롤 높이를 검증해요.
Future<void> loadAppFonts() async {
  await (FontLoader('Pretendard')
        ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))
        ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await (FontLoader('CupertinoIcons')..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      ))
      .load();
  await (FontLoader('NaruSymbolsRounded')..addFont(
        rootBundle.load(
          'assets/fonts/material_symbols/MaterialSymbolsRounded.ttf',
        ),
      ))
      .load();
  await (FontLoader('NaruSymbolsRoundedFilled')..addFont(
        rootBundle.load(
          'assets/fonts/material_symbols/MaterialSymbolsRoundedFilled.ttf',
        ),
      ))
      .load();
}
