import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/design_system/app_colors.dart';
import 'package:naru/features/chat/data/chat_video_transcoder.dart';
import 'package:naru/features/chat/presentation/chat_video_trim_editor.dart';

final Uint8List _testPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'
  'CAYAAAAfFcSJAAAADUlEQVR42mNk+M/w'
  'HwAEAQH/2p3KAAAAAElFTkSuQmCC',
);

Widget _buildTimeline({
  ChatVideoTrimRange range = const ChatVideoTrimRange(
    start: Duration.zero,
    end: Duration(seconds: 10),
  ),
  Duration position = Duration.zero,
  List<Uint8List> thumbnails = const <Uint8List>[],
  void Function(ChatVideoTrimRange range, Duration previewPosition)?
  onTrimChanged,
  ValueChanged<Duration>? onPositionChanged,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(393, 852),
        padding: EdgeInsets.only(bottom: 34),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned(
              left: ChatVideoTrimTimeline.horizontalMargin,
              right: ChatVideoTrimTimeline.horizontalMargin,
              bottom:
                  ChatVideoTrimTimeline.referenceControlCenterFromBottom -
                  ChatVideoTrimTimeline.trackHeight / 2,
              child: ChatVideoTrimTimeline(
                duration: const Duration(seconds: 10),
                trimRange: range,
                position: position,
                thumbnails: thumbnails,
                onTrimChanged: onTrimChanged ?? (_, _) {},
                onPositionChanged: onPositionChanged ?? (_) {},
                onInteractionEnd: () {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('playback control matches the iOS timeline-side segment', (
    WidgetTester tester,
  ) async {
    bool pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ChatVideoTrimPlaybackControl(
            isPlaying: false,
            onPressed: () {
              pressed = true;
            },
          ),
        ),
      ),
    );

    final Finder playback = find.byKey(
      const ValueKey<String>('video-trim-playback'),
    );
    expect(
      tester.getSize(playback),
      const Size(
        ChatVideoTrimPlaybackControl.width,
        ChatVideoTrimPlaybackControl.height,
      ),
    );
    final DecoratedBox playbackBackground = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('video-trim-playback-background')),
    );
    expect(
      (playbackBackground.decoration as BoxDecoration).color,
      AppColors.incomingMessageBubble,
    );
    expect(
      (playbackBackground.decoration as BoxDecoration).borderRadius,
      const BorderRadius.horizontal(
        left: Radius.circular(ChatVideoTrimTimeline.cornerRadius),
      ),
    );
    expect(
      ((playbackBackground.decoration as BoxDecoration).border as Border)
          .right
          .width,
      1,
    );
    await tester.tap(playback);
    expect(pressed, isTrue);
  });

  testWidgets('trim timeline matches the measured iOS height and placement', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(_buildTimeline());

    final Finder timeline = find.byKey(
      const ValueKey<String>('video-trim-timeline'),
    );
    final Finder track = find.byKey(const ValueKey<String>('video-trim-track'));
    final Rect trackRect = tester.getRect(track);

    expect(tester.getSize(timeline), const Size(363, 74));
    expect(trackRect, const Rect.fromLTWH(15, 774.5, 363, 51));
    expect(trackRect.center.dy, 800);
    expect(
      trackRect.top -
          tester
              .getRect(
                find.byKey(const ValueKey<String>('video-trim-start-label')),
              )
              .bottom,
      ChatVideoTrimTimeline.textToTrackGap,
    );

    final Text startLabel = tester.widget<Text>(
      find.byKey(const ValueKey<String>('video-trim-start-label')),
    );
    final Text endLabel = tester.widget<Text>(
      find.byKey(const ValueKey<String>('video-trim-end-label')),
    );

    expect(startLabel.data, '0:00');
    expect(endLabel.data, '0:10');
    expect(startLabel.style?.fontSize, 12);
    expect(startLabel.style?.fontWeight, FontWeight.w400);
    expect(ChatVideoTrimTimeline.handleWidth, 18);
    expect(ChatVideoTrimTimeline.frameThickness, 5);
    expect(ChatVideoTrimTimeline.thumbnailCount, 13);
    final Row thumbnailRow = tester.widget<Row>(
      find.byKey(const ValueKey<String>('video-trim-thumbnails')),
    );
    expect(thumbnailRow.crossAxisAlignment, CrossAxisAlignment.stretch);
    final Rect playheadRect = tester.getRect(
      find.byKey(const ValueKey<String>('video-trim-playhead')),
    );
    expect(
      playheadRect,
      Rect.fromLTWH(
        trackRect.left + ChatVideoTrimTimeline.handleWidth,
        trackRect.top + ChatVideoTrimTimeline.playheadVerticalInset,
        4,
        45,
      ),
    );

    final DecoratedBox trackBackground = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('video-trim-track-background')),
    );
    expect(
      (trackBackground.decoration as BoxDecoration).color,
      Colors.transparent,
    );

    final CustomPaint initialSelection = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>('video-trim-selection')),
    );
    expect(
      (initialSelection.painter as dynamic).color,
      AppColors.incomingMessageBubble,
    );
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    (initialSelection.painter as dynamic).paint(
      canvas,
      const Size(363, ChatVideoTrimTimeline.trackHeight),
    );
    final ui.Image selectionImage = (await tester.runAsync<ui.Image>(
      () => recorder.endRecording().toImage(
        363,
        ChatVideoTrimTimeline.trackHeight.toInt(),
      ),
    ))!;
    final ByteData selectionPixels = (await tester.runAsync<ByteData?>(
      () => selectionImage.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    int alphaAt(int x, int y) =>
        selectionPixels.getUint8((y * selectionImage.width + x) * 4 + 3);
    Color colorAt(int x, int y) {
      final int offset = (y * selectionImage.width + x) * 4;

      return Color.fromARGB(
        selectionPixels.getUint8(offset + 3),
        selectionPixels.getUint8(offset),
        selectionPixels.getUint8(offset + 1),
        selectionPixels.getUint8(offset + 2),
      );
    }

    expect(alphaAt(17, 0), 255);
    expect(alphaAt(345, 0), 255);
    expect(alphaAt(0, 0), lessThan(255));
    expect(alphaAt(362, 0), lessThan(255));
    expect(colorAt(9, 25), AppColors.grey900);
    selectionImage.dispose();

    await tester.pumpWidget(
      _buildTimeline(
        thumbnails: List<Uint8List>.filled(
          ChatVideoTrimTimeline.thumbnailCount,
          _testPng,
        ),
      ),
    );
    final DecoratedBox loadedTrackBackground = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('video-trim-track-background')),
    );
    expect(
      (loadedTrackBackground.decoration as BoxDecoration).color,
      AppColors.incomingMessageBubble,
    );

    await tester.pumpWidget(
      _buildTimeline(
        range: const ChatVideoTrimRange(
          start: Duration(seconds: 2),
          end: Duration(seconds: 10),
        ),
      ),
    );

    final CustomPaint trimmedSelection = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>('video-trim-selection')),
    );
    expect(
      (trimmedSelection.painter as dynamic).color,
      AppColors.outgoingMessageBubble,
    );
  });

  testWidgets('right handle changes the selected end and keeps one second', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    ChatVideoTrimRange range = const ChatVideoTrimRange(
      start: Duration.zero,
      end: Duration(seconds: 10),
    );

    await tester.pumpWidget(
      _buildTimeline(
        onTrimChanged: (ChatVideoTrimRange next, Duration previewPosition) {
          range = next;
        },
      ),
    );

    final Rect track = tester.getRect(
      find.byKey(const ValueKey<String>('video-trim-track')),
    );
    final TestGesture gesture = await tester.startGesture(
      Offset(track.left + 341, track.center.dy),
    );
    await gesture.moveTo(Offset(track.left + 180.5, track.center.dy));
    await gesture.up();

    expect(range.end.inMilliseconds, closeTo(5000, 40));

    final TestGesture minimumGesture = await tester.startGesture(
      Offset(track.left + 341, track.center.dy),
    );
    await minimumGesture.moveTo(Offset(track.left + 20, track.center.dy));
    await minimumGesture.up();

    expect(range.duration, const Duration(seconds: 1));
  });

  testWidgets('handle drag shows only its moving time and hides the playhead', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    ChatVideoTrimRange range = const ChatVideoTrimRange(
      start: Duration.zero,
      end: Duration(seconds: 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 852),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: Stack(
                  children: [
                    Positioned(
                      left: ChatVideoTrimTimeline.horizontalMargin,
                      right: ChatVideoTrimTimeline.horizontalMargin,
                      bottom:
                          ChatVideoTrimTimeline
                              .referenceControlCenterFromBottom -
                          ChatVideoTrimTimeline.trackHeight / 2,
                      child: ChatVideoTrimTimeline(
                        duration: const Duration(seconds: 10),
                        trimRange: range,
                        position: range.start,
                        thumbnails: <Uint8List>[],
                        onTrimChanged:
                            (
                              ChatVideoTrimRange next,
                              Duration previewPosition,
                            ) {
                              setState(() {
                                range = next;
                              });
                            },
                        onPositionChanged: (_) {},
                        onInteractionEnd: () {},
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    final Finder trackFinder = find.byKey(
      const ValueKey<String>('video-trim-track'),
    );
    final Rect track = tester.getRect(trackFinder);
    final TestGesture gesture = await tester.startGesture(
      Offset(track.left + 20, track.center.dy),
    );
    await gesture.moveTo(Offset(track.left + 140, track.center.dy));
    await tester.pump();

    final Finder startLabel = find.byKey(
      const ValueKey<String>('video-trim-start-label'),
    );
    expect(startLabel, findsOneWidget);
    expect(tester.getCenter(startLabel).dx, closeTo(track.left + 131, 1));
    expect(
      find.byKey(const ValueKey<String>('video-trim-end-label')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('video-trim-playhead')),
      findsNothing,
    );

    await gesture.up();
    await tester.pump();

    expect(startLabel, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('video-trim-end-label')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('video-trim-playhead')),
      findsOneWidget,
    );

    final TestGesture endGesture = await tester.startGesture(
      Offset(track.left + 341, track.center.dy),
    );
    await endGesture.moveTo(Offset(track.left + 260, track.center.dy));
    await tester.pump();

    final Finder endLabel = find.byKey(
      const ValueKey<String>('video-trim-end-label'),
    );
    expect(startLabel, findsNothing);
    expect(endLabel, findsOneWidget);
    expect(tester.getCenter(endLabel).dx, closeTo(track.left + 269, 1));
    expect(
      find.byKey(const ValueKey<String>('video-trim-playhead')),
      findsNothing,
    );

    await endGesture.up();
    await tester.pump();

    expect(startLabel, findsNothing);
    expect(endLabel, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('video-trim-playhead')),
      findsOneWidget,
    );
  });

  testWidgets('dragging the frame strip scrubs inside the trim range', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    Duration position = Duration.zero;

    await tester.pumpWidget(
      _buildTimeline(
        onPositionChanged: (Duration next) {
          position = next;
        },
      ),
    );

    final Rect track = tester.getRect(
      find.byKey(const ValueKey<String>('video-trim-track')),
    );
    await tester.tapAt(Offset(track.left + 180.5, track.center.dy));

    expect(position.inMilliseconds, closeTo(5000, 40));
  });
}
