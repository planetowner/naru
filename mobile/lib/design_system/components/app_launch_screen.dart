import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';

final class AppLaunchGate extends StatefulWidget {
  const AppLaunchGate({required this.isReady, required this.child, super.key});

  final bool isReady;
  final Widget child;

  @override
  State<AppLaunchGate> createState() => _AppLaunchGateState();
}

final class _AppLaunchGateState extends State<AppLaunchGate> {
  static const Duration _minimumDisplayDuration = Duration(seconds: 2);
  static const Duration _fadeDuration = Duration(milliseconds: 250);

  Timer? _minimumDisplayTimer;
  bool _isRevealing = false;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _minimumDisplayTimer = Timer(_minimumDisplayDuration, () {
      _minimumDisplayTimer = null;
      _revealIfReady();
    });
  }

  @override
  void didUpdateWidget(AppLaunchGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _revealIfReady();
  }

  @override
  void dispose() {
    _minimumDisplayTimer?.cancel();
    super.dispose();
  }

  void _revealIfReady() {
    // 최소 표시 시간과 첫 화면 준비가 모두 끝나야 로딩 화면이 드러나지 않아요.
    if (_isRevealing || !widget.isReady || _minimumDisplayTimer != null) {
      return;
    }

    setState(() {
      _isRevealing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 첫 화면을 미리 생성해 데이터를 불러오되, 준비 전에는 화면에 노출하지 않아요.
        Offstage(offstage: !_isRevealing, child: widget.child),
        if (!_isDismissed)
          AnimatedOpacity(
            opacity: _isRevealing ? 0 : 1,
            duration: _fadeDuration,
            curve: Curves.easeOut,
            onEnd: () {
              setState(() {
                _isDismissed = true;
              });
            },
            child: const AppLaunchScreen(),
          ),
      ],
    );
  }
}

final class AppLaunchScreen extends StatelessWidget {
  const AppLaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.launchBackground,
        body: Center(
          // iOS LaunchScreen.storyboard와 같은 이미지, 크기, 화면 중심을 사용해요.
          child: Image.asset(
            'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
            width: 144,
            height: 144,
            fit: BoxFit.contain,
            semanticLabel: 'JuliaTalk',
          ),
        ),
      ),
    );
  }
}
