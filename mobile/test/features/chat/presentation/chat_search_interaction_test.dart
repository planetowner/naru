import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/design_system/app_colors.dart';
import 'package:naru/features/chat/data/chat_api.dart';
import 'package:naru/features/chat/domain/chat_message.dart';
import 'package:naru/features/chat/presentation/chat_conversation_view.dart';

InkWell _searchButton(WidgetTester tester, Finder finder) {
  return tester.widget<InkWell>(
    find.descendant(of: finder, matching: find.byType(InkWell)),
  );
}

Color? _matchBackgroundColor(
  WidgetTester tester, {
  required String messageId,
  required String query,
}) {
  final Finder richTextFinder = find.descendant(
    of: find.byKey(ValueKey<String>('original-message-$messageId')),
    matching: find.byType(RichText),
  );

  Color? findColor(InlineSpan span) {
    if (span is! TextSpan) {
      return null;
    }

    if (span.text == query) {
      return span.style?.backgroundColor;
    }

    for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
      final Color? color = findColor(child);

      if (color != null) {
        return color;
      }
    }

    return null;
  }

  for (final RichText richText in tester.widgetList<RichText>(richTextFinder)) {
    final Color? color = findColor(richText.text);

    if (color != null) {
      return color;
    }
  }

  return null;
}

List<ChatMessage> _messagesWithPhotoBeforeMatches(int historyCount) =>
    <ChatMessage>[
      for (int index = 0; index < historyCount; index++)
        ChatMessage(
          id: 'history-$index',
          senderId: '2',
          recipientId: '1',
          content: index == 2 ? '에바 이전 메시지' : 'Earlier message $index',
          createdAt: DateTime(2026, 10, 25, 12, index),
        ),
      ChatMessage(
        id: 'photo-before-matches',
        senderId: '1',
        recipientId: '2',
        content: '',
        createdAt: DateTime(2026, 10, 26, 22, 27),
        photoAttachments: [
          ChatPhotoAttachment(
            assetId: 'search-photo',
            width: 1200,
            height: 1200,
            previewBytes: base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABmJLR0QA'
              '/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gMQ'
              'FwcdLl4wmwAAAAtJREFUCNdjYAACAAAFAAHiJgWbAAAAAElFTkSuQmCC',
            ),
          ),
        ],
      ),
      for (int index = 0; index < 2; index++)
        ChatMessage(
          id: 'match-$index',
          senderId: '1',
          recipientId: '2',
          content: '에바',
          createdAt: DateTime(2026, 10, 27, 1, 27, index),
        ),
    ];

void main() {
  testWidgets('search navigation follows KakaoTalk result direction', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationView(
          initialMessages: <ChatMessage>[
            ChatMessage(
              id: 'oldest',
              senderId: '1',
              recipientId: '2',
              content: '자기야 사랑해',
              createdAt: DateTime(2026, 7, 10, 17, 26),
            ),
            ChatMessage(
              id: 'older',
              senderId: '1',
              recipientId: '2',
              content: '자기야 오늘 뭐 먹었어?',
              createdAt: DateTime(2026, 7, 10, 19, 14),
            ),
            ChatMessage(
              id: 'newer',
              senderId: '1',
              recipientId: '2',
              content: '자기야 안녕~~',
              createdAt: DateTime(2026, 7, 10, 19, 47),
            ),
            ChatMessage(
              id: 'newest',
              senderId: '2',
              recipientId: '1',
              content: '안녕 자기야',
              createdAt: DateTime(2026, 7, 10, 19, 48),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(
      find.byKey(const ValueKey<String>('chat-search-input')),
      '자기',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('4 matches'), findsNothing);
    expect(find.text('Newest first'), findsNothing);

    final Finder olderButtonFinder = find.byKey(
      const ValueKey<String>('chat-search-older'),
    );
    final Finder newerButtonFinder = find.byKey(
      const ValueKey<String>('chat-search-newer'),
    );

    expect(_searchButton(tester, olderButtonFinder).onTap, isNotNull);
    expect(_searchButton(tester, newerButtonFinder).onTap, isNull);

    final double toolbarCenter = tester
        .getCenter(find.byKey(const ValueKey<String>('chat-search-toolbar')))
        .dx;
    final double counterCenter = tester
        .getCenter(find.byKey(const ValueKey<String>('chat-search-counter')))
        .dx;

    expect(counterCenter, moreOrLessEquals(toolbarCenter, epsilon: 0.5));

    await tester.tap(olderButtonFinder);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('2/4'), findsOneWidget);

    await tester.tap(olderButtonFinder);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(olderButtonFinder);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('4/4'), findsOneWidget);

    expect(_searchButton(tester, olderButtonFinder).onTap, isNull);
    expect(_searchButton(tester, newerButtonFinder).onTap, isNotNull);

    await tester.tap(newerButtonFinder);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('3/4'), findsOneWidget);
  });

  testWidgets('active outgoing search match has distinct contrast', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationView(
          initialMessages: <ChatMessage>[
            ChatMessage(
              id: 'incoming-match',
              senderId: '2',
              recipientId: '1',
              content: '안녕 자기야',
              createdAt: DateTime(2026, 7, 10, 19, 47),
            ),
            ChatMessage(
              id: 'outgoing-match',
              senderId: '1',
              recipientId: '2',
              content: '자기야 안녕~~',
              createdAt: DateTime(2026, 7, 10, 19, 48),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(
      find.byKey(const ValueKey<String>('chat-search-input')),
      '자기',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      _matchBackgroundColor(tester, messageId: 'outgoing-match', query: '자기'),
      AppColors.blue900,
    );
    expect(
      _matchBackgroundColor(tester, messageId: 'incoming-match', query: '자기'),
      AppColors.primary.withAlpha(54),
    );

    await tester.tap(find.byKey(const ValueKey<String>('chat-search-older')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      _matchBackgroundColor(tester, messageId: 'incoming-match', query: '자기'),
      AppColors.blue200,
    );
    expect(
      _matchBackgroundColor(tester, messageId: 'outgoing-match', query: '자기'),
      AppColors.white.withAlpha(76),
    );
  });

  testWidgets('search mode preserves the bottom visible message anchor', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      tester.view.resetViewInsets();
      await tester.binding.setSurfaceSize(null);
    });

    final List<ChatMessage> messages = List<ChatMessage>.generate(
      20,
      (int index) => ChatMessage(
        id: 'anchor-$index',
        senderId: index.isEven ? '1' : '2',
        recipientId: index.isEven ? '2' : '1',
        content: index == 19 ? '你好 宝宝' : 'message $index',
        createdAt: DateTime(2026, 7, 10, 19, index),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: ChatConversationView(initialMessages: messages)),
    );
    await tester.pumpAndSettle();

    final Finder anchorBubble = find.byKey(
      const ValueKey<String>('incoming-bubble-anchor-19'),
    );
    final Finder composer = find.byKey(
      const ValueKey<String>('message-composer-default'),
    );

    final double initialGap =
        tester.getTopLeft(composer).dy - tester.getBottomLeft(anchorBubble).dy;

    for (int cycle = 0; cycle < 3; cycle++) {
      await tester.tap(find.byTooltip('Search'));
      await tester.pump(const Duration(milliseconds: 100));

      final Finder searchToolbar = find.byKey(
        const ValueKey<String>('chat-search-toolbar'),
      );

      for (final double keyboardHeight in <double>[60, 120, 180, 240, 300]) {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        await tester.pump(const Duration(milliseconds: 80));

        final double searchGap =
            tester.getTopLeft(searchToolbar).dy -
            tester.getBottomLeft(anchorBubble).dy;

        expect(
          searchGap,
          moreOrLessEquals(initialGap, epsilon: 1),
          reason:
              'search entry drifted at $keyboardHeight px '
              'on cycle ${cycle + 1}',
        );
      }

      await tester.tap(find.byTooltip('Close search'));
      await tester.pump(const Duration(milliseconds: 80));

      for (final double keyboardHeight in <double>[240, 180, 120, 60, 0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        await tester.pump(const Duration(milliseconds: 80));

        final double restoredGap =
            tester.getTopLeft(composer).dy -
            tester.getBottomLeft(anchorBubble).dy;

        expect(
          restoredGap,
          moreOrLessEquals(initialGap, epsilon: 1),
          reason:
              'search exit drifted at $keyboardHeight px '
              'on cycle ${cycle + 1}',
        );
      }
    }
  });

  testWidgets('opening search keeps a short conversation in place', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
    final messages = _messagesWithPhotoBeforeMatches(1);
    final history = Completer<ChatConversationPage>();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationView(
          initialMessages: messages,
          onLoadSearchPage: ({beforeMessageId}) => history.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bubble = find.byKey(const ValueKey('outgoing-bubble-match-1'));
    final double initialBottom = tester.getBottomLeft(bubble).dy;
    final double composerTop = tester
        .getTopLeft(find.byKey(const ValueKey('message-composer-default')))
        .dy;
    expect(composerTop - initialBottom, greaterThan(12));

    await tester.tap(find.byTooltip('Search'));
    for (int frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getBottomLeft(bubble).dy,
        closeTo(initialBottom, 0.5),
        reason: '검색 상단이나 로딩 안내가 나타나도 대화를 아래로 밀면 안 돼요.',
      );
    }
    expect(find.text('Searching chat history…'), findsOneWidget);
    history.complete(ChatConversationPage(messages: messages, hasMore: false));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(bubble).dy, closeTo(initialBottom, 0.5));
    expect(find.text('Searching chat history…'), findsNothing);

    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(bubble).dy, closeTo(initialBottom, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search matches remain between the header and toolbar as the keyboard closes',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.reset);

      final messages = _messagesWithPhotoBeforeMatches(20);
      await tester.pumpWidget(
        MaterialApp(home: ChatConversationView(initialMessages: messages)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();

      void expectMessageVisible(String bubbleKey) {
        final Rect bubble = tester.getRect(find.byKey(ValueKey(bubbleKey)));
        final Rect header = tester.getRect(
          find.byKey(const ValueKey('chat-search-top-bar')),
        );
        final Rect toolbar = tester.getRect(
          find.byKey(const ValueKey('chat-search-toolbar')),
        );
        expect(bubble.top, greaterThanOrEqualTo(header.bottom));
        expect(bubble.bottom, lessThan(toolbar.top));
      }

      for (final double height in [60, 120, 180, 240, 300, 346]) {
        tester.view.viewInsets = FakeViewPadding(bottom: height);
        tester.view.padding = const FakeViewPadding(top: 59);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.enterText(
        find.byKey(const ValueKey('chat-search-input')),
        '에바',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      expectMessageVisible('outgoing-bubble-match-1');

      final toolbar = find.byKey(const ValueKey('chat-search-toolbar'));
      final double initialGap =
          tester.getTopLeft(toolbar).dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('outgoing-bubble-match-1')),
              )
              .dy;
      double previousToolbarBottom = tester.getBottomLeft(toolbar).dy;
      // 홈 인디케이터보다 낮은 키보드 프레임에서도 내려갔다 다시 튀면 안 돼요.
      for (final double height in [
        300,
        240,
        180,
        120,
        60,
        44,
        40,
        34,
        24,
        10,
        1,
        0,
      ]) {
        tester.view.viewInsets = FakeViewPadding(bottom: height);
        if (height == 0) {
          tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
        }
        await tester.pump(const Duration(milliseconds: 80));
        expectMessageVisible('outgoing-bubble-match-1');
        final double toolbarBottom = tester.getBottomLeft(toolbar).dy;
        expect(
          toolbarBottom,
          lessThanOrEqualTo(852 - 34),
          reason: '검색 바가 홈 인디케이터 영역 안으로 내려가면 안 돼요.',
        );
        expect(
          toolbarBottom,
          greaterThanOrEqualTo(previousToolbarBottom),
          reason: '키보드가 닫힐 때 검색 바가 반대 방향으로 튀면 안 돼요.',
        );
        expect(
          tester.getTopLeft(toolbar).dy -
              tester
                  .getBottomLeft(
                    find.byKey(const ValueKey('outgoing-bubble-match-1')),
                  )
                  .dy,
          closeTo(initialGap, 0.5),
          reason: '메시지와 검색 바가 같은 이동을 따라야 해요.',
        );
        previousToolbarBottom = toolbarBottom;
      }
      await tester.pumpAndSettle();

      for (final bubbleKey in [
        'outgoing-bubble-match-0',
        'incoming-bubble-history-2',
      ]) {
        await tester.tap(find.byKey(const ValueKey('chat-search-older')));
        await tester.pumpAndSettle();
        expectMessageVisible(bubbleKey);
      }
      expect(find.text('3/3'), findsOneWidget);
      for (final bubbleKey in [
        'outgoing-bubble-match-0',
        'outgoing-bubble-match-1',
      ]) {
        await tester.tap(find.byKey(const ValueKey('chat-search-newer')));
        await tester.pumpAndSettle();
        expectMessageVisible(bubbleKey);
      }
      expect(find.text('1/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search results stay hidden until the edited query is submitted',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationView(
            currentUserPreferredLanguage: 'ko',
            initialMessages: <ChatMessage>[
              ChatMessage(
                id: 'match',
                senderId: '2',
                recipientId: '1',
                content: '안녕 자기야',
                createdAt: DateTime(2026, 7, 10, 19, 48),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Search'));
      await tester.pump(const Duration(milliseconds: 250));

      final Finder searchInput = find.byKey(
        const ValueKey<String>('chat-search-input'),
      );

      await tester.enterText(searchInput, '자기');
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const ValueKey<String>('chat-search-counter')),
        findsNothing,
      );

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('1/1'), findsOneWidget);

      await tester.tap(searchInput);
      await tester.enterText(searchInput, '없는 검색어');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('1/1'), findsNothing);
      expect(find.text('검색 결과 없음'), findsNothing);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('검색 결과 없음'), findsOneWidget);
      expect(find.text('0/0'), findsNothing);
    },
  );

  testWidgets('empty submitted search uses the Chinese no-results label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatConversationView(currentUserPreferredLanguage: 'zh-CN'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(
      find.byKey(const ValueKey<String>('chat-search-input')),
      '没有的内容',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('查无结果'), findsOneWidget);
    expect(find.text('0/0'), findsNothing);
  });
}
