import 'package:flutter/material.dart';

import '../app_icons.dart';
import '../app_spacing.dart';

abstract final class AppMediaViewerChrome {
  static const Color backgroundColor = Color(0xFF202020);
  static const Color buttonColor = Color(0xFF272727);
  static const Color buttonBorderColor = Color(0xFF4E4E4E);
  static const Color foregroundColor = Color(0xFFE8E8E8);
  // 미디어 제목과 재생 시간은 아이콘보다 밝은 기존 글자색을 사용해요.
  static const Color labelColor = Color(0xFFF2F2F2);
  static const double buttonDimension = 44;
  static const double horizontalMargin = AppSpacing.space16;
  static const double trailingSpacing = 23;
  static const Duration controlsAnimationDuration = Duration(milliseconds: 200);

  static double topBarHeight(double topPadding) {
    return topPadding + buttonDimension + trailingSpacing;
  }

  static Curve controlsSlideCurve(bool visible) {
    return visible ? Curves.easeOutCubic : Curves.linear;
  }
}

// 뷰어와 편집 컨트롤은 같은 속도로 이동·페이드하고 숨겨진 동안 터치를 막아요.
final class AppMediaViewerControlsTransition extends StatelessWidget {
  const AppMediaViewerControlsTransition({
    required this.visible,
    required this.hiddenOffset,
    required this.child,
    this.slideKey,
    this.opacityKey,
    super.key,
  });

  final bool visible;
  final Offset hiddenOffset;
  final Widget child;
  final Key? slideKey;
  final Key? opacityKey;

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    key: slideKey,
    duration: AppMediaViewerChrome.controlsAnimationDuration,
    curve: AppMediaViewerChrome.controlsSlideCurve(visible),
    offset: visible ? Offset.zero : hiddenOffset,
    child: IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        key: opacityKey,
        duration: AppMediaViewerChrome.controlsAnimationDuration,
        opacity: visible ? 1 : 0,
        child: child,
      ),
    ),
  );
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

  // 버튼 표면과 터치 영역의 모서리를 같은 높이 기준으로 계산해요.
  static BorderRadius borderRadiusForHeight(double height) {
    return BorderRadius.circular(height / 2);
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = borderRadiusForHeight(height);

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

// 일반·미디어 버튼은 같은 표면과 터치 처리를 쓰고 크기·색상·내용만 바꿔요.
final class AppMediaViewerChromeButton extends StatelessWidget {
  const AppMediaViewerChromeButton({
    required this.onPressed,
    required this.child,
    this.dimension = AppMediaViewerChrome.buttonDimension,
    this.width,
    this.shape = BoxShape.circle,
    this.backgroundColor = AppMediaViewerChrome.buttonColor,
    this.borderColor = AppMediaViewerChrome.buttonBorderColor,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double dimension;
  final double? width;
  final BoxShape shape;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AppTopBarButtonSurface(
      width: width ?? dimension,
      height: dimension,
      color: backgroundColor,
      borderColor: borderColor,
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
      // 직접 그리던 상단 화살표의 고정 방향을 유지해요.
      child: Icon(
        AppIcons.back,
        size: 24,
        color: color,
        textDirection: TextDirection.ltr,
      ),
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
  static const double iconToButtonRatio =
      referenceDimension / referenceButtonDimension;

  final double dimension;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: Icon(AppIcons.edit, size: dimension, color: color),
    );
  }
}
