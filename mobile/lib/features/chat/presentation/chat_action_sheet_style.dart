import 'package:flutter/material.dart';

import '../../../design_system/app_radius.dart';

abstract final class ChatActionSheetStyle {
  static const BorderRadius borderRadius = BorderRadius.vertical(
    top: Radius.circular(AppRadius.radius24),
  );

  static const double horizontalPadding = 18;

  // 통화와 녹음은 같은 여백을 쓰고, 기기 안전 영역은 호출부에서 더해요.
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(
    horizontalPadding,
    26,
    horizontalPadding,
    22,
  );
}
