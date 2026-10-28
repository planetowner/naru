import '../../../support/localized_test_app.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/design_system/app_icons.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/features/chat/domain/chat_message.dart';
import 'package:naru/features/chat/presentation/chat_conversation_view.dart';

import '../../../support/load_app_fonts.dart';

ChatMessage voice({
  bool outgoing = false,
  ChatTranscriptionStatus status = ChatTranscriptionStatus.transcribed,
  ChatTranslationStatus translation = ChatTranslationStatus.translated,
  String content = '今天过得怎么样？我很想你。',
}) => ChatMessage(
  id: 'voice',
  senderId: outgoing ? '1' : '2',
  recipientId: outgoing ? '2' : '1',
  createdAt: DateTime(2026, 10, 27, 19, 30),
  content: status == ChatTranscriptionStatus.transcribed ? content : '',
  transcriptionStatus: status,
  translationStatus: translation,
  translatedContent: translation == ChatTranslationStatus.translated
      ? '오늘 하루 어땠어? 많이 보고 싶어.'
      : null,
  sourceLanguage: 'zh-CN',
  translatedLanguage: 'ko',
  voiceMemoAttachment: const ChatVoiceMemoAttachment(
    duration: Duration(seconds: 12),
    waveformSamples: [0.1, 0.4, 0.9, 0.6, 0.3, 0.5, 0.8, 0.2],
  ),
);

Widget screen(
  ChatMessage message, {
  String language = 'ko',
  ChatMessageProcessingRetrier? retryTranscription,
  ChatMessageProcessingRetrier? retryTranslation,
  double textScale = 1,
}) => LocalizedTestApp(
  language: language,

  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: ChatConversationView(
    currentUserName: 'Me',
    otherParticipantName: 'Lia',

    initialMessages: [message],

    onRetryTranscription: retryTranscription,
    onRetryTranslation: retryTranslation,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets(
    'incoming voice toggles original and translation below the player',
    (tester) async {
      await tester.pumpWidget(screen(voice()));
      await tester.pumpAndSettle();
      final Finder player = find.byIcon(AppIcons.play);
      final Finder original = find.text('오늘 하루 어땠어? 많이 보고 싶어.');
      expect(original, findsOneWidget);
      expect(
        tester.getTopLeft(original).dy,
        greaterThan(tester.getBottomLeft(player).dy),
      );
      final double playerY = tester.getTopLeft(player).dy;
      await tester.tap(original);
      await tester.pumpAndSettle();
      expect(find.text('今天过得怎么样？我很想你。'), findsOneWidget);
      expect(player, findsOneWidget);
      expect(tester.getTopLeft(player).dy, closeTo(playerY, 24));
      await tester.tap(find.text('今天过得怎么样？我很想你。'));
      await tester.pumpAndSettle();
      expect(original, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'server updates move voice from pending to readable original and translation',
    (tester) async {
      await tester.pumpWidget(
        screen(voice(status: ChatTranscriptionStatus.transcribing)),
      );
      await tester.pump();
      expect(find.text('텍스트로 변환 중...'), findsOneWidget);
      expect(find.text('今天过得怎么样？我很想你。'), findsNothing);

      await tester.pumpWidget(
        screen(voice(translation: ChatTranslationStatus.translating)),
      );
      await tester.pump();
      expect(find.text('今天过得怎么样？我很想你。'), findsOneWidget);
      expect(find.text('번역 중...'), findsOneWidget);

      await tester.pumpWidget(screen(voice()));
      await tester.pumpAndSettle();
      expect(find.text('번역 중...'), findsNothing);
      expect(find.text('오늘 하루 어땠어? 많이 보고 싶어.'), findsOneWidget);
    },
  );

  for (final bool outgoing in [false, true]) {
    testWidgets(
      '${outgoing ? 'sender' : 'recipient'} can retry transcription and see network failure',
      (tester) async {
        int requests = 0;
        final Completer<ChatMessage> retry = Completer<ChatMessage>();
        await tester.pumpWidget(
          screen(
            voice(outgoing: outgoing, status: ChatTranscriptionStatus.failed),
            retryTranscription: ({required String messageId}) {
              expect(messageId, 'voice');
              requests++;
              return retry.future;
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('음성을 텍스트로 변환하지 못했어요.'), findsOneWidget);
        await tester.tap(find.text('다시 해보기'));
        await tester.pump();
        expect(requests, 1);
        expect(find.text('텍스트로 변환 중...'), findsOneWidget);
        expect(find.text('다시 해보기'), findsNothing);
        expect(find.byIcon(AppIcons.play), findsOneWidget);
        retry.completeError(StateError('offline'));
        await tester.pumpAndSettle();
        expect(find.text('다시 해보기'), findsOneWidget);
        expect(find.text('음성을 텍스트로 변환하지 못했어요.'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'translation retry keeps transcript visible and uses the translation callback',
    (tester) async {
      final Completer<ChatMessage> retry = Completer<ChatMessage>();
      await tester.pumpWidget(
        screen(
          voice(translation: ChatTranslationStatus.failed),
          retryTranslation: ({required String messageId}) => retry.future,
          retryTranscription: ({required String messageId}) =>
              throw StateError('must not transcribe again'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('다시 해보기'));
      await tester.pump();
      expect(find.text('今天过得怎么样？我很想你。'), findsOneWidget);
      expect(find.text('번역 중...'), findsOneWidget);
      retry.complete(voice());
      await tester.pumpAndSettle();
      expect(find.text('오늘 하루 어땠어? 많이 보고 싶어.'), findsOneWidget);
    },
  );

  testWidgets('outgoing and same-language transcripts use original text', (
    tester,
  ) async {
    await tester.pumpWidget(screen(voice(outgoing: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今天过得怎么样？我很想你。'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 하루 어땠어? 많이 보고 싶어.'), findsNothing);
    await tester.pumpWidget(
      screen(voice(content: '안녕하세요').copyWith(translatedContent: '안녕하세요')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('안녕하세요'));
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요'), findsOneWidget);
    expect(find.text('오늘 하루 어땠어? 많이 보고 싶어.'), findsNothing);
  });

  testWidgets('transcription updates preserve the selected audio position', (
    tester,
  ) async {
    final ChatMessage serverMessage = voice().copyWith(
      voiceMemoAttachment: const ChatVoiceMemoAttachment(
        duration: Duration(seconds: 12),
        mediaAssetId: 'recorded-audio',
        waveformSamples: [0.2, 0.8],
      ),
    );
    final ChatMessage localMessage = serverMessage.copyWith(
      transcriptionStatus: ChatTranscriptionStatus.transcribing,
      voiceMemoAttachment: const ChatVoiceMemoAttachment(
        duration: Duration(seconds: 12),
        mediaAssetId: 'recorded-audio',
        localPath: '/private/tmp/recorded-audio.m4a',
        waveformSamples: [0.2, 0.8],
      ),
    );
    await tester.pumpWidget(screen(localMessage));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final Finder waveform = find
        .descendant(
          of: find.byKey(const ValueKey('incoming-bubble-voice')),
          matching: find.byWidgetPredicate(
            (widget) => widget is CustomPaint && widget.painter != null,
          ),
        )
        .first;
    await tester.tap(waveform);
    await tester.pump();
    double progress() =>
        (tester.widget<CustomPaint>(waveform).painter as dynamic).progress
            as double;
    expect(progress(), closeTo(0.5, 0.01));
    await tester.pumpWidget(screen(serverMessage));
    await tester.pumpAndSettle();
    expect(progress(), closeTo(0.5, 0.01));
  });

  testWidgets(
    'Chinese processing copy and enlarged text fit a narrow voice card',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        screen(
          voice(status: ChatTranscriptionStatus.transcribing),
          language: 'zh-CN',
          textScale: 1.5,
        ),
      );
      await tester.pump();
      expect(find.text('正在转为文字...'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 900);
      await tester.pumpWidget(screen(voice(), textScale: 2));
      await tester.pumpAndSettle();
      final Rect bubble = tester.getRect(
        find.byKey(const ValueKey('incoming-bubble-voice')),
      );
      final Rect text = tester.getRect(find.text('오늘 하루 어땠어? 많이 보고 싶어.'));
      expect(text.left, greaterThan(bubble.left));
      expect(text.right, lessThan(bubble.right));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'older voice without transcription retains the original player height',
    (tester) async {
      await tester.pumpWidget(
        screen(voice(status: ChatTranscriptionStatus.none)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('incoming-bubble-voice')))
            .height,
        56,
      );
      expect(find.text('텍스트로 변환 중...'), findsNothing);
    },
  );
}
