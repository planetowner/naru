import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/components/app_media_viewer_chrome.dart';

final class ChatMediaViewerScaffold extends StatefulWidget {
  const ChatMediaViewerScaffold({
    required this.onTap,
    required this.onClose,
    required this.children,
    super.key,
  });

  final VoidCallback onTap;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  State<ChatMediaViewerScaffold> createState() =>
      _ChatMediaViewerScaffoldState();
}

final class _ChatMediaViewerScaffoldState
    extends State<ChatMediaViewerScaffold> {
  double _verticalDragDistance = 0;

  void _handleVerticalDragStart(DragStartDetails details) {
    _verticalDragDistance = 0;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    _verticalDragDistance += details.delta.dy;
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;

    // 사진과 동영상은 같은 거리와 속도 기준으로 닫아요.
    if (_verticalDragDistance.abs() > 82 || velocity.abs() > 650) {
      widget.onClose();
    }

    _verticalDragDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppMediaViewerChrome.backgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppMediaViewerChrome.backgroundColor,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onVerticalDragStart: _handleVerticalDragStart,
          onVerticalDragUpdate: _handleVerticalDragUpdate,
          onVerticalDragEnd: _handleVerticalDragEnd,
          child: Stack(fit: StackFit.expand, children: widget.children),
        ),
      ),
    );
  }
}
