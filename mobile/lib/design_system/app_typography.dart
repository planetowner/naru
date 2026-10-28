import 'package:flutter/material.dart';

final class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Pretendard';

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight bold = FontWeight.w700;

  // 상대방 이름·검색·통화의 제목을 같은 18/27 굵기로 맞춰요.
  static final TextStyle navigationTitle = subTypography9.copyWith(
    fontWeight: bold,
  );

  // Yeoul 원본의 Auto 행간을 명시해 상위 테마의 고정 행간이 섞이지 않게 해요.
  static const TextStyle code = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: bold,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: bold,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: bold,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: bold,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: bold,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: bold,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: bold,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: regular,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: regular,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: regular,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: regular,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: bold,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: bold,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: regular,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle captionSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: regular,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  static const TextStyle finePrint = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: regular,
    height: kTextHeightNone,
    letterSpacing: 0,
  );

  // 기존 채팅·미디어의 배치에 연결된 크기와 행간은 전용 규격으로 유지해요.
  static const TextStyle typography1 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 30,
    height: 40 / 30,
    fontWeight: regular,
  );

  static const TextStyle typography2 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 26,
    height: 35 / 26,
    fontWeight: regular,
  );

  static const TextStyle subTypography5 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 24,
    height: 33 / 24,
    fontWeight: regular,
  );

  static const TextStyle typography3 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 22,
    height: 31 / 22,
    fontWeight: regular,
  );

  static const TextStyle typography4 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 20,
    height: 29 / 20,
    fontWeight: regular,
  );

  static const TextStyle subTypography9 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 18,
    height: 27 / 18,
    fontWeight: regular,
  );

  static const TextStyle typography5 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 17,
    height: 25.5 / 17,
    fontWeight: regular,
  );

  static const TextStyle subTypography10 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: regular,
  );

  static const TextStyle typography6 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 15,
    height: 22.5 / 15,
    fontWeight: regular,
  );

  static const TextStyle subTypography11 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 14,
    height: 21 / 14,
    fontWeight: regular,
  );

  static const TextStyle typography7 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 13,
    height: 19.5 / 13,
    fontWeight: regular,
  );

  static const TextStyle subTypography12 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: regular,
  );

  static const TextStyle subTypography13 = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: regular,
  );
}
