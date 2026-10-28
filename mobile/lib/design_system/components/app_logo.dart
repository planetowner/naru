import 'package:flutter/material.dart';

final class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 144, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/naru-symbol.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'naru',
    );
  }
}
