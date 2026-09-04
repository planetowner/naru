import 'package:flutter/material.dart';

abstract final class AppMediaViewerChrome {
  static const Color backgroundColor = Color(0xFF202020);
  static const Color buttonColor = Color(0xFF272727);
  static const Color buttonBorderColor = Color(0xFF4E4E4E);
  static const Color foregroundColor = Color(0xFFE8E8E8);
  static const double buttonDimension = 44;
  static const double horizontalMargin = 16;
  static const double trailingSpacing = 23;
  static const Duration controlsAnimationDuration = Duration(milliseconds: 200);

  static double topBarHeight(double topPadding) {
    return topPadding + buttonDimension + trailingSpacing;
  }

  static Curve controlsSlideCurve(bool visible) {
    return visible ? Curves.easeOutCubic : Curves.linear;
  }
}

final class AppMediaViewerControlTapRegion extends StatelessWidget {
  const AppMediaViewerControlTapRegion({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: () {},
      child: child,
    );
  }
}

final class AppTopBarButtonSurface extends StatelessWidget {
  const AppTopBarButtonSurface({
    required this.height,
    required this.color,
    required this.borderColor,
    required this.child,
    this.width,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  final double? width;
  final double height;
  final Color color;
  final Color borderColor;
  final Widget child;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(height / 2);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: shape,
                borderRadius: shape == BoxShape.circle ? null : borderRadius,
                border: Border.all(color: borderColor, width: 0.67),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: shape == BoxShape.circle ? const CircleBorder() : null,
            borderRadius: shape == BoxShape.circle ? null : borderRadius,
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}

final class AppMediaViewerChromeButton extends StatelessWidget {
  const AppMediaViewerChromeButton({
    required this.onPressed,
    required this.child,
    this.dimension = AppMediaViewerChrome.buttonDimension,
    this.width,
    this.shape = BoxShape.circle,
    super.key,
  });

  final VoidCallback onPressed;
  final Widget child;
  final double dimension;
  final double? width;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return AppTopBarButtonSurface(
      width: width ?? dimension,
      height: dimension,
      color: AppMediaViewerChrome.buttonColor,
      borderColor: AppMediaViewerChrome.buttonBorderColor,
      shape: shape,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape == BoxShape.circle ? const CircleBorder() : null,
        child: Center(child: child),
      ),
    );
  }
}

final class AppTopBarBackIcon extends StatelessWidget {
  const AppTopBarBackIcon({
    this.color = AppMediaViewerChrome.foregroundColor,
    super.key,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: const Size.square(24),
      child: CustomPaint(painter: _AppTopBarBackIconPainter(color: color)),
    );
  }
}

final class AppMediaEditIcon extends StatelessWidget {
  const AppMediaEditIcon({
    this.dimension = referenceDimension,
    this.color = AppMediaViewerChrome.foregroundColor,
    super.key,
  });

  static const double referenceButtonDimension = 48;
  static const double referenceDimension = 24;
  static const double referenceStrokeWidth = 1.5;
  static const double iconToButtonRatio =
      referenceDimension / referenceButtonDimension;

  final double dimension;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: CustomPaint(painter: _AppMediaEditIconPainter(color: color)),
    );
  }
}

final class _AppMediaEditIconPainter extends CustomPainter {
  const _AppMediaEditIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale =
        size.shortestSide / AppMediaEditIcon.referenceDimension;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppMediaEditIcon.referenceStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path pencil = Path()
      ..moveTo(2.25, 17)
      ..lineTo(15.5, 3.75)
      ..quadraticBezierTo(17.25, 2, 19, 3.75)
      ..lineTo(20.5, 5.25)
      ..quadraticBezierTo(22.25, 7, 20.5, 8.75)
      ..lineTo(7.25, 22)
      ..lineTo(2.25, 22)
      ..close();

    // 원 크기가 달라도 펜슬의 외곽과 선 굵기를 같은 비율로 줄여요.
    canvas
      ..save()
      ..translate(
        (size.width - AppMediaEditIcon.referenceDimension * scale) / 2,
        (size.height - AppMediaEditIcon.referenceDimension * scale) / 2,
      )
      ..scale(scale);
    canvas.drawPath(pencil, paint);
    canvas.drawLine(const Offset(14, 5.25), const Offset(19, 10.25), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppMediaEditIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

final class _AppTopBarBackIconPainter extends CustomPainter {
  const _AppTopBarBackIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(16, 3)
        ..lineTo(6, 12)
        ..lineTo(16, 21),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AppTopBarBackIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
