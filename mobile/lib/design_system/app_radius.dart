import 'package:flutter/widgets.dart';

final class AppRadius {
  AppRadius._();

  static const double radius4 = 4;
  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius24 = 24;
  static const double radiusFull = 999;

  static const BorderRadius borderRadius4 = BorderRadius.all(
    Radius.circular(radius4),
  );

  static const BorderRadius borderRadius8 = BorderRadius.all(
    Radius.circular(radius8),
  );

  static const BorderRadius borderRadius12 = BorderRadius.all(
    Radius.circular(radius12),
  );

  static const BorderRadius borderRadius16 = BorderRadius.all(
    Radius.circular(radius16),
  );

  static const BorderRadius borderRadius24 = BorderRadius.all(
    Radius.circular(radius24),
  );

  static const BorderRadius borderRadiusFull = BorderRadius.all(
    Radius.circular(radiusFull),
  );
}
