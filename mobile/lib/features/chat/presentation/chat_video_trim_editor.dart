import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/app_typography.dart';
import '../../../design_system/components/app_media_viewer_chrome.dart';
import '../data/chat_video_transcoder.dart';

final class ChatVideoTrimEditor extends StatefulWidget {
  const ChatVideoTrimEditor({
    required this.inputPath,
    required this.duration,
    required this.active,
    required this.controlsVisible,
    required this.controlCenterFromBottom,
    required this.onTrimChanged,
    super.key,
  });

  final String inputPath;
  final Duration duration;
  final bool active;
  final bool controlsVisible;
  final double controlCenterFromBottom;
  final ValueChanged<ChatVideoTrimRange> onTrimChanged;

  @override
  State<ChatVideoTrimEditor> createState() => _ChatVideoTrimEditorState();
}

final class _ChatVideoTrimEditorState extends State<ChatVideoTrimEditor>
    with AutomaticKeepAliveClientMixin {
  static const MethodChannel _channel = MethodChannel(
    'juliatalk/video-transcoder',
  );

  VideoPlayerController? _controller;
  List<Uint8List> _thumbnails = const <Uint8List>[];
  late ChatVideoTrimRange _trimRange;
  Duration? _scrubPosition;
  bool _controllerReady = false;
  bool _resettingAfterPlayback = false;

  Duration get _resolvedDuration {
    final VideoPlayerController? controller = _controller;

    if (controller != null && controller.value.isInitialized) {
      return controller.value.duration;
    }

    return widget.duration;
  }

  Duration get _position {
    final Duration? scrubPosition = _scrubPosition;

    if (scrubPosition != null) {
      return scrubPosition;
    }

    final VideoPlayerController? controller = _controller;

    if (controller != null && controller.value.isInitialized) {
      return controller.value.position;
    }

    return _trimRange.start;
  }

  bool get _isPlaying {
    final VideoPlayerController? controller = _controller;

    return controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _trimRange = ChatVideoTrimRange(start: Duration.zero, end: widget.duration);
    unawaited(_initializeVideo());
    unawaited(_loadTimelineThumbnails());
  }

  @override
  void didUpdateWidget(ChatVideoTrimEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.active && !widget.active) {
      unawaited(_controller?.pause());
    }
  }

  @override
  void dispose() {
    final VideoPlayerController? controller = _controller;
    _controller = null;
    controller?.removeListener(_handlePlaybackChanged);
    unawaited(controller?.dispose());
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final VideoPlayerController controller = VideoPlayerController.file(
      File(widget.inputPath),
    );
    _controller = controller;

    try {
      await controller.initialize();

      if (!mounted || _controller != controller) {
        return;
      }

      final Duration actualDuration = controller.value.duration;
      if (actualDuration > Duration.zero) {
        _trimRange = ChatVideoTrimRange(
          start: Duration.zero,
          end: actualDuration,
        );
      }
      controller.addListener(_handlePlaybackChanged);
      setState(() {
        _controllerReady = true;
      });
    } on Object {
      if (!mounted || _controller != controller) {
        return;
      }

      setState(() {
        _controllerReady = false;
      });
    }
  }

  Future<void> _loadTimelineThumbnails() async {
    try {
      final List<Object?>? values = await _channel
          .invokeListMethod<Object?>('timeline-thumbnails', <String, Object>{
            'input_path': widget.inputPath,
            'count': ChatVideoTrimTimeline.thumbnailCount,
            'maximum_dimension': 180,
          });
      final List<Uint8List> thumbnails = <Uint8List>[
        for (final Object? value in values ?? const <Object?>[])
          if (value is Uint8List) value,
      ];

      if (!mounted) {
        return;
      }

      setState(() {
        _thumbnails = thumbnails;
      });
    } on PlatformException {
      // 프레임을 불러오지 못해도 재생과 트리밍 동작은 유지해요.
    }
  }

  void _handlePlaybackChanged() {
    final VideoPlayerController? controller = _controller;

    if (!mounted ||
        controller == null ||
        !controller.value.isInitialized ||
        _resettingAfterPlayback) {
      return;
    }

    if (controller.value.isPlaying &&
        controller.value.position >= _trimRange.end) {
      unawaited(_resetAfterPlayback());
      return;
    }

    setState(() {});
  }

  Future<void> _resetAfterPlayback() async {
    final VideoPlayerController? controller = _controller;

    if (controller == null || _resettingAfterPlayback) {
      return;
    }

    _resettingAfterPlayback = true;
    await controller.pause();
    await controller.seekTo(_trimRange.start);

    if (mounted && _controller == controller) {
      setState(() {
        _scrubPosition = null;
      });
    }
    _resettingAfterPlayback = false;
  }

  Future<void> _togglePlayback() async {
    final VideoPlayerController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      if (mounted && _controller == controller) {
        setState(() {});
      }
      return;
    }

    final Duration position = controller.value.position;
    if (position < _trimRange.start || position >= _trimRange.end) {
      await controller.seekTo(_trimRange.start);
    }
    await controller.play();

    if (mounted && _controller == controller) {
      setState(() {
        _scrubPosition = null;
      });
    }
  }

  void _handleTrimChanged(ChatVideoTrimRange range, Duration previewPosition) {
    final VideoPlayerController? controller = _controller;
    unawaited(controller?.pause());
    unawaited(controller?.seekTo(previewPosition));

    setState(() {
      _trimRange = range;
      _scrubPosition = previewPosition;
    });
    widget.onTrimChanged(range);
  }

  void _handleScrubChanged(Duration position) {
    final VideoPlayerController? controller = _controller;
    unawaited(controller?.pause());
    unawaited(controller?.seekTo(position));

    setState(() {
      _scrubPosition = position;
    });
  }

  void _handleTimelineInteractionEnd() {
    setState(() {
      _scrubPosition = null;
    });
  }

  Widget _buildVideo() {
    final VideoPlayerController? controller = _controller;

    if (!_controllerReady ||
        controller == null ||
        !controller.value.isInitialized) {
      return const ColoredBox(color: AppMediaViewerChrome.backgroundColor);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size videoSize = controller.value.size;
        final double videoRatio = videoSize.width / videoSize.height;
        final double viewportRatio =
            constraints.maxWidth / constraints.maxHeight;
        final bool sameOrientation = (videoRatio >= 1) == (viewportRatio >= 1);
        final BoxFit fit =
            sameOrientation &&
                (math.log(videoRatio / viewportRatio)).abs() < 0.45
            ? BoxFit.cover
            : BoxFit.contain;

        return FittedBox(
          fit: fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox.fromSize(
            size: videoSize,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Stack(
      key: const ValueKey<String>('video-trim-editor'),
      fit: StackFit.expand,
      children: [
        _buildVideo(),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, 0.45),
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x00000000), Color(0xD9000000)],
              ),
            ),
          ),
        ),
        Positioned(
          left: ChatVideoTrimTimeline.horizontalMargin,
          right: ChatVideoTrimTimeline.horizontalMargin,
          bottom:
              widget.controlCenterFromBottom -
              ChatVideoTrimTimeline.trackHeight / 2,
          child: AnimatedSlide(
            key: const ValueKey<String>('video-trim-timeline-slide'),
            duration: AppMediaViewerChrome.controlsAnimationDuration,
            curve: AppMediaViewerChrome.controlsSlideCurve(
              widget.controlsVisible,
            ),
            offset: widget.controlsVisible ? Offset.zero : const Offset(0, 1),
            child: IgnorePointer(
              ignoring: !widget.controlsVisible,
              child: AnimatedOpacity(
                key: const ValueKey<String>('video-trim-timeline-opacity'),
                duration: AppMediaViewerChrome.controlsAnimationDuration,
                opacity: widget.controlsVisible ? 1 : 0,
                child: AppMediaViewerControlTapRegion(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ChatVideoTrimPlaybackControl(
                        isPlaying: _isPlaying,
                        onPressed: () {
                          unawaited(_togglePlayback());
                        },
                      ),
                      Expanded(
                        child: ChatVideoTrimTimeline(
                          duration: _resolvedDuration,
                          trimRange: _trimRange,
                          position: _position,
                          thumbnails: _thumbnails,
                          onTrimChanged: _handleTrimChanged,
                          onPositionChanged: _handleScrubChanged,
                          onInteractionEnd: _handleTimelineInteractionEnd,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class ChatVideoTrimPlaybackControl extends StatelessWidget {
  const ChatVideoTrimPlaybackControl({
    required this.isPlaying,
    required this.onPressed,
    super.key,
  });

  static const double width = 48;
  static const double height = ChatVideoTrimTimeline.trackHeight;
  static const double cornerRadius = ChatVideoTrimTimeline.cornerRadius;
  // iOS 사진 편집기의 3× 캡처에서 재생 아이콘 모서리 곡면을 8px로 측정했어요.
  static const double playIconCornerInset = 2.75;

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('video-trim-playback'),
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          key: const ValueKey<String>('video-trim-playback-background'),
          decoration: const BoxDecoration(
            color: AppColors.incomingMessageBubble,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(cornerRadius),
            ),
            border: Border(right: BorderSide(color: AppColors.white, width: 1)),
          ),
          child: CustomPaint(
            painter: _VideoTrimPlaybackIconPainter(isPlaying: isPlaying),
          ),
        ),
      ),
    );
  }
}

enum _VideoTrimInteraction { start, end, position }

final class ChatVideoTrimTimeline extends StatefulWidget {
  const ChatVideoTrimTimeline({
    required this.duration,
    required this.trimRange,
    required this.position,
    required this.thumbnails,
    required this.onTrimChanged,
    required this.onPositionChanged,
    required this.onInteractionEnd,
    super.key,
  });

  // iOS 사진 편집기의 3× 캡처에서 트랙 높이가 153px로 측정됐어요.
  static const double trackHeight = 51;
  static const double horizontalMargin = 15;
  static const double cornerRadius = 8;
  static const double frameThickness = 5;
  static const double textHeight = 12;
  static const double textToTrackGap = 11;
  static const double totalHeight = textHeight + textToTrackGap + trackHeight;
  static const double handleWidth = 18;
  static const double playheadWidth = 4;
  static const double playheadVerticalInset = 3;
  // iOS 편집기의 3× 캡처에서 279pt 프레임 영역이 13칸으로 나뉘었어요.
  static const int thumbnailCount = 13;
  // 사진 편집 캡처에서 PencilKit 툴바 중앙은 화면 하단에서 52pt였어요.
  static const double referenceControlCenterFromBottom = 52;
  static const Duration minimumTrimDuration = Duration(seconds: 1);

  final Duration duration;
  final ChatVideoTrimRange trimRange;
  final Duration position;
  final List<Uint8List> thumbnails;
  final void Function(ChatVideoTrimRange range, Duration previewPosition)
  onTrimChanged;
  final ValueChanged<Duration> onPositionChanged;
  final VoidCallback onInteractionEnd;

  @override
  State<ChatVideoTrimTimeline> createState() => _ChatVideoTrimTimelineState();
}

final class _ChatVideoTrimTimelineState extends State<ChatVideoTrimTimeline> {
  static const double _handleHitRadius = 24;

  _VideoTrimInteraction _interaction = _VideoTrimInteraction.position;
  _VideoTrimInteraction? _lastHandleInteraction;
  bool _isHandleDragging = false;
  late ChatVideoTrimRange _workingRange;

  @override
  void initState() {
    super.initState();
    _workingRange = widget.trimRange;
  }

  @override
  void didUpdateWidget(ChatVideoTrimTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _workingRange = widget.trimRange;
  }

  double _fraction(Duration value) {
    final int total = widget.duration.inMicroseconds;

    if (total <= 0) {
      return 0;
    }

    return (value.inMicroseconds / total).clamp(0, 1).toDouble();
  }

  Duration _durationForFraction(double fraction) {
    return Duration(
      microseconds: (widget.duration.inMicroseconds * fraction).round(),
    );
  }

  double _trimBoundaryX(Duration value, double width) {
    final double contentWidth = width - ChatVideoTrimTimeline.handleWidth * 2;

    return ChatVideoTrimTimeline.handleWidth + contentWidth * _fraction(value);
  }

  double _positionX(Duration value, double width) {
    final double contentWidth = width - ChatVideoTrimTimeline.handleWidth * 2;

    return ChatVideoTrimTimeline.handleWidth + contentWidth * _fraction(value);
  }

  _VideoTrimInteraction _interactionFor(double x, double width) {
    final double startX = _trimBoundaryX(_workingRange.start, width);
    final double endX = _trimBoundaryX(_workingRange.end, width);
    final double startDistance = (x - startX).abs();
    final double endDistance = (x - endX).abs();

    if (startDistance <= _handleHitRadius || endDistance <= _handleHitRadius) {
      return startDistance <= endDistance
          ? _VideoTrimInteraction.start
          : _VideoTrimInteraction.end;
    }

    return _VideoTrimInteraction.position;
  }

  double _fractionForX(
    double x,
    double width,
    _VideoTrimInteraction interaction,
  ) {
    final double inset = ChatVideoTrimTimeline.handleWidth;
    final double contentWidth = width - inset * 2;

    if (contentWidth <= 0) {
      return 0;
    }

    return ((x - inset) / contentWidth).clamp(0, 1).toDouble();
  }

  void _startInteraction(Offset position, double width) {
    _workingRange = widget.trimRange;
    final _VideoTrimInteraction interaction = _interactionFor(
      position.dx,
      width,
    );

    setState(() {
      _interaction = interaction;
      _isHandleDragging = interaction != _VideoTrimInteraction.position;
      _lastHandleInteraction = _isHandleDragging ? interaction : null;
    });
  }

  void _endInteraction() {
    if (_isHandleDragging) {
      setState(() {
        _isHandleDragging = false;
      });
    }
    widget.onInteractionEnd();
  }

  void _resumeDragInteraction() {
    setState(() {
      _isHandleDragging = _interaction != _VideoTrimInteraction.position;
      if (_isHandleDragging) {
        _lastHandleInteraction = _interaction;
      }
    });
  }

  void _updateInteraction(Offset position, double width) {
    final Duration rawValue = _durationForFraction(
      _fractionForX(position.dx, width, _interaction),
    );
    final Duration minimum =
        widget.duration < ChatVideoTrimTimeline.minimumTrimDuration
        ? widget.duration
        : ChatVideoTrimTimeline.minimumTrimDuration;

    switch (_interaction) {
      case _VideoTrimInteraction.start:
        final Duration maximumStart = _workingRange.end - minimum;
        final Duration start = rawValue > maximumStart
            ? maximumStart
            : rawValue;
        _workingRange = ChatVideoTrimRange(
          start: start,
          end: _workingRange.end,
        );
        widget.onTrimChanged(_workingRange, start);
        break;
      case _VideoTrimInteraction.end:
        final Duration minimumEnd = _workingRange.start + minimum;
        final Duration end = rawValue < minimumEnd ? minimumEnd : rawValue;
        _workingRange = ChatVideoTrimRange(
          start: _workingRange.start,
          end: end,
        );
        widget.onTrimChanged(_workingRange, end);
        break;
      case _VideoTrimInteraction.position:
        Duration value = rawValue;
        if (value < _workingRange.start) {
          value = _workingRange.start;
        } else if (value > _workingRange.end) {
          value = _workingRange.end;
        }
        widget.onPositionChanged(value);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle timeStyle = AppTypography.subTypography12.copyWith(
      color: AppColors.white,
      height: 1,
      fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
    );

    return SizedBox(
      key: const ValueKey<String>('video-trim-timeline'),
      height: ChatVideoTrimTimeline.totalHeight,
      child: Column(
        children: [
          SizedBox(
            height: ChatVideoTrimTimeline.textHeight,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                final double startCenter =
                    _trimBoundaryX(widget.trimRange.start, width) -
                    ChatVideoTrimTimeline.handleWidth / 2;
                final double endCenter =
                    _trimBoundaryX(widget.trimRange.end, width) +
                    ChatVideoTrimTimeline.handleWidth / 2;

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (_lastHandleInteraction != _VideoTrimInteraction.end)
                      Positioned.fill(
                        child: CustomSingleChildLayout(
                          delegate: _VideoTrimTimeLabelLayout(
                            centerX: startCenter,
                          ),
                          child: Text(
                            _formatVideoTrimTime(widget.trimRange.start),
                            key: const ValueKey<String>(
                              'video-trim-start-label',
                            ),
                            style: timeStyle,
                          ),
                        ),
                      ),
                    if (_lastHandleInteraction != _VideoTrimInteraction.start)
                      Positioned.fill(
                        child: CustomSingleChildLayout(
                          delegate: _VideoTrimTimeLabelLayout(
                            centerX: endCenter,
                          ),
                          child: Text(
                            _formatVideoTrimTime(widget.trimRange.end),
                            key: const ValueKey<String>('video-trim-end-label'),
                            style: timeStyle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: ChatVideoTrimTimeline.textToTrackGap),
          SizedBox(
            key: const ValueKey<String>('video-trim-track'),
            height: ChatVideoTrimTimeline.trackHeight,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                final double contentWidth =
                    width - ChatVideoTrimTimeline.handleWidth * 2;
                final double startX = _trimBoundaryX(
                  widget.trimRange.start,
                  width,
                );
                final double endX = _trimBoundaryX(widget.trimRange.end, width);
                final double positionX = _positionX(widget.position, width);
                final double playheadLeft =
                    (positionX - ChatVideoTrimTimeline.playheadWidth / 2)
                        .clamp(
                          startX,
                          math.max(
                            startX,
                            endX - ChatVideoTrimTimeline.playheadWidth,
                          ),
                        )
                        .toDouble();
                final bool isTrimmed =
                    widget.trimRange.start > Duration.zero ||
                    widget.trimRange.end < widget.duration;
                final bool thumbnailsReady =
                    widget.thumbnails.length ==
                    ChatVideoTrimTimeline.thumbnailCount;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (TapDownDetails details) {
                    _startInteraction(details.localPosition, width);
                  },
                  onTapUp: (TapUpDetails details) {
                    _updateInteraction(details.localPosition, width);
                    _endInteraction();
                  },
                  onTapCancel: _endInteraction,
                  onHorizontalDragDown: (DragDownDetails details) {
                    _startInteraction(details.localPosition, width);
                  },
                  onHorizontalDragStart: (DragStartDetails details) {
                    _resumeDragInteraction();
                    _updateInteraction(details.localPosition, width);
                  },
                  onHorizontalDragUpdate: (DragUpdateDetails details) {
                    _updateInteraction(details.localPosition, width);
                  },
                  onHorizontalDragEnd: (_) {
                    _endInteraction();
                  },
                  onHorizontalDragCancel: _endInteraction,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(
                        ChatVideoTrimTimeline.cornerRadius,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            key: const ValueKey<String>(
                              'video-trim-track-background',
                            ),
                            decoration: BoxDecoration(
                              // 실제 프레임 전에는 아래의 동영상 화면을 그대로 보여줘요.
                              color: thumbnailsReady
                                  ? AppColors.incomingMessageBubble
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(
                                  ChatVideoTrimTimeline.cornerRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: ChatVideoTrimTimeline.handleWidth,
                          top: ChatVideoTrimTimeline.frameThickness,
                          width: contentWidth,
                          bottom: ChatVideoTrimTimeline.frameThickness,
                          child: ClipRect(
                            child: Row(
                              key: const ValueKey<String>(
                                'video-trim-thumbnails',
                              ),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: List<Widget>.generate(
                                ChatVideoTrimTimeline.thumbnailCount,
                                (int index) => Expanded(
                                  child: index < widget.thumbnails.length
                                      ? Image.memory(
                                          widget.thumbnails[index],
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          filterQuality: FilterQuality.low,
                                        )
                                      : const SizedBox.expand(),
                                ),
                                growable: false,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: ChatVideoTrimTimeline.handleWidth,
                          top: ChatVideoTrimTimeline.frameThickness,
                          width: math.max(
                            0,
                            startX - ChatVideoTrimTimeline.handleWidth,
                          ),
                          bottom: ChatVideoTrimTimeline.frameThickness,
                          child: ColoredBox(
                            color: AppColors.black.withAlpha(150),
                          ),
                        ),
                        Positioned(
                          left: endX,
                          right: ChatVideoTrimTimeline.handleWidth,
                          top: ChatVideoTrimTimeline.frameThickness,
                          bottom: ChatVideoTrimTimeline.frameThickness,
                          child: ColoredBox(
                            color: AppColors.black.withAlpha(150),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            key: const ValueKey<String>('video-trim-selection'),
                            painter: _VideoTrimSelectionPainter(
                              startX: startX,
                              endX: endX,
                              color: isTrimmed
                                  ? AppColors.outgoingMessageBubble
                                  : AppColors.incomingMessageBubble,
                            ),
                          ),
                        ),
                        if (!_isHandleDragging)
                          Positioned(
                            left: playheadLeft,
                            top: ChatVideoTrimTimeline.playheadVerticalInset,
                            width: ChatVideoTrimTimeline.playheadWidth,
                            height:
                                ChatVideoTrimTimeline.trackHeight -
                                ChatVideoTrimTimeline.playheadVerticalInset * 2,
                            child: const DecoratedBox(
                              key: ValueKey<String>('video-trim-playhead'),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                    ChatVideoTrimTimeline.playheadWidth / 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _VideoTrimTimeLabelLayout extends SingleChildLayoutDelegate {
  const _VideoTrimTimeLabelLayout({required this.centerX});

  final double centerX;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double left = (centerX - childSize.width / 2)
        .clamp(0, math.max(0, size.width - childSize.width))
        .toDouble();

    return Offset(left, math.max(0, size.height - childSize.height));
  }

  @override
  bool shouldRelayout(covariant _VideoTrimTimeLabelLayout oldDelegate) {
    return centerX != oldDelegate.centerX;
  }
}

final class _VideoTrimSelectionPainter extends CustomPainter {
  const _VideoTrimSelectionPainter({
    required this.startX,
    required this.endX,
    required this.color,
  });

  static const double _handleMarkWidth = 3;
  static const double _handleMarkHeight = 20;
  static const double _radius = 3;

  final double startX;
  final double endX;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint selectionPaint = Paint()..color = color;
    final double handleWidth = ChatVideoTrimTimeline.handleWidth;
    final Rect leftHandle = Rect.fromLTWH(
      startX - handleWidth,
      0,
      handleWidth,
      size.height,
    );
    final Rect rightHandle = Rect.fromLTWH(endX, 0, handleWidth, size.height);

    const Radius outerRadius = Radius.circular(_radius);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        leftHandle,
        topLeft: outerRadius,
        bottomLeft: outerRadius,
      ),
      selectionPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rightHandle,
        topRight: outerRadius,
        bottomRight: outerRadius,
      ),
      selectionPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        leftHandle.right,
        0,
        math.max(0, rightHandle.left - leftHandle.right),
        ChatVideoTrimTimeline.frameThickness,
      ),
      selectionPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        leftHandle.right,
        size.height - ChatVideoTrimTimeline.frameThickness,
        math.max(0, rightHandle.left - leftHandle.right),
        ChatVideoTrimTimeline.frameThickness,
      ),
      selectionPaint,
    );

    final Paint handleMarkPaint = Paint()..color = AppColors.grey900;
    final Radius markRadius = Radius.circular(_handleMarkWidth / 2);
    for (final double centerX in <double>[
      leftHandle.center.dx,
      rightHandle.center.dx,
    ]) {
      final Rect mark = Rect.fromCenter(
        center: Offset(centerX, size.height / 2),
        width: _handleMarkWidth,
        height: _handleMarkHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(mark, markRadius),
        handleMarkPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VideoTrimSelectionPainter oldDelegate) {
    return startX != oldDelegate.startX ||
        endX != oldDelegate.endX ||
        color != oldDelegate.color;
  }
}

final class _VideoTrimPlaybackIconPainter extends CustomPainter {
  const _VideoTrimPlaybackIconPainter({required this.isPlaying});

  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = AppColors.grey900;

    if (isPlaying) {
      const double barWidth = 5;
      const double barHeight = 17;
      final double top = (size.height - barHeight) / 2;
      for (final double centerX in <double>[
        size.width / 2 - 4,
        size.width / 2 + 4,
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(centerX, top + barHeight / 2),
              width: barWidth,
              height: barHeight,
            ),
            const Radius.circular(2.5),
          ),
          paint,
        );
      }
      return;
    }

    final Offset center = size.center(const Offset(1, 0));
    canvas.drawPath(
      _roundedTrianglePath(<Offset>[
        center + const Offset(-9, -9),
        center + const Offset(9, 0),
        center + const Offset(-9, 9),
      ], ChatVideoTrimPlaybackControl.playIconCornerInset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _VideoTrimPlaybackIconPainter oldDelegate) {
    return isPlaying != oldDelegate.isPlaying;
  }
}

Path _roundedTrianglePath(List<Offset> vertices, double cornerInset) {
  Offset pointToward(Offset from, Offset to) {
    final Offset delta = to - from;

    return from + delta / delta.distance * cornerInset;
  }

  final Path path = Path();
  for (int index = 0; index < vertices.length; index += 1) {
    final Offset vertex = vertices[index];
    final Offset previous = vertices[(index - 1) % vertices.length];
    final Offset next = vertices[(index + 1) % vertices.length];
    final Offset beforeCorner = pointToward(vertex, previous);
    final Offset afterCorner = pointToward(vertex, next);

    if (index == 0) {
      path.moveTo(beforeCorner.dx, beforeCorner.dy);
    } else {
      path.lineTo(beforeCorner.dx, beforeCorner.dy);
    }
    path.quadraticBezierTo(
      vertex.dx,
      vertex.dy,
      afterCorner.dx,
      afterCorner.dy,
    );
  }

  return path..close();
}

String _formatVideoTrimTime(Duration duration) {
  final int totalSeconds = duration.inSeconds;
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  final String secondText = seconds.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$secondText';
  }

  return '$minutes:$secondText';
}
