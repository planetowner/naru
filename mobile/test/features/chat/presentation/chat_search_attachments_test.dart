import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/design_system/app_icons.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/features/chat/data/chat_api.dart';
import 'package:naru/features/chat/domain/chat_message.dart';
import 'package:naru/features/chat/presentation/chat_conversation_view.dart';

import '../../../support/load_app_fonts.dart';

ChatMessage fileMessage(String id, String name) => ChatMessage(
  id: id,
  senderId: '2',
  recipientId: '1',
  content: name,
  createdAt: DateTime(2026, 10, 16),
  fileAttachment: ChatFileAttachment(name: name, sizeBytes: 1024),
);
Future<void> openSearch(
  WidgetTester tester,
  ChatConversationView view, {
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: view));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Search'));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> tab(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('chat-search-tab-$name')));
  await tester.pumpAndSettle();
}

final searchInput = find.byKey(const ValueKey('chat-search-input'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  testWidgets('file query, empty state and clearing use real attachments', (
    tester,
  ) async {
    await openSearch(
      tester,
      ChatConversationView(
        initialMessages: [
          fileMessage('a', 'Search notes.pdf'),
          fileMessage('b', 'budget.xlsx'),
        ],
      ),
    );
    await tab(tester, 'files');
    expect(
      find.byKey(const ValueKey('search-card-a:attachment')),
      findsOneWidget,
    );
    await tester.enterText(searchInput, 'NOTES');
    await tester.pump();
    expect(tester.getSize(searchInput).height, 46);
    expect(
      find.byKey(const ValueKey('search-card-a:attachment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('search-card-b:attachment')),
      findsNothing,
    );
    await tester.enterText(searchInput, 'missing');
    await tester.pump();
    expect(find.text('No files found'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear search'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('search-card-b:attachment')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('older pages are indexed, failed page retries with its cursor', (
    tester,
  ) async {
    final calls = <String?>[];
    bool fail = true;
    await openSearch(
      tester,
      ChatConversationView(
        initialMessages: [fileMessage('latest', 'recent.pdf')],
        onLoadSearchPage: ({beforeMessageId}) async {
          calls.add(beforeMessageId);
          if (beforeMessageId == null) {
            return ChatConversationPage(
              messages: [fileMessage('latest', 'recent.pdf')],
              hasMore: true,
            );
          }
          if (fail) {
            fail = false;
            throw StateError('offline');
          }
          return ChatConversationPage(
            messages: [fileMessage('older', 'archive.pdf')],
            hasMore: false,
          );
        },
      ),
    );
    await tab(tester, 'files');
    expect(find.text('Couldn’t load all messages'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, [null, 'latest', 'latest']);
    expect(
      find.byKey(const ValueKey('search-card-older:attachment')),
      findsOneWidget,
    );
    expect(find.text('Couldn’t load all messages'), findsNothing);
  });
  for (final category in ['media', 'links', 'files']) {
    testWidgets('$category date filter can be selected and cleared', (
      tester,
    ) async {
      ChatMessage message(String id, int day) => ChatMessage(
        id: id,
        senderId: '2',
        recipientId: '1',
        createdAt: DateTime(2026, 10, day),
        content: category == 'links' ? 'https://$id.test/a' : '',
        photoAttachments: category == 'media'
            ? [ChatPhotoAttachment(assetId: id, width: 100, height: 100)]
            : const [],
        fileAttachment: category == 'files'
            ? ChatFileAttachment(name: '$id.pdf', sizeBytes: 1024)
            : null,
      );
      Finder result(String id) => find.byKey(
        ValueKey(switch (category) {
          'media' => 'search-media-$id:0',
          'links' => 'search-card-$id:https://$id.test/a',
          _ => 'search-card-$id:attachment',
        }),
      );
      await openSearch(
        tester,
        ChatConversationView(
          initialMessages: const [],
          onLoadSearchPage: ({beforeMessageId}) async => ChatConversationPage(
            hasMore: false,
            messages: [message('today', 16), message('older', 14)],
          ),
        ),
        size: const Size(320, 640),
      );
      await tab(tester, category);
      final dateButton = find.byTooltip('Filter by date');
      final buttonRect = tester.getRect(dateButton);
      expect(buttonRect.size, const Size(46, 46));
      expect(buttonRect.right, 320 - 16);
      expect(find.text('All dates'), findsNothing);
      expect(find.byTooltip('Clear date filter'), findsNothing);

      await tester.tap(dateButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      expect(result('older'), findsOneWidget);
      expect(result('today'), findsNothing);
      expect(tester.getRect(dateButton), buttonRect);
      final clearDate = find.byTooltip('Clear date filter');
      expect(
        find.descendant(of: clearDate, matching: find.text('Oct 14')),
        findsOneWidget,
      );
      expect(tester.getSize(clearDate).height, 36);
      expect(tester.getTopLeft(clearDate).dx, 16);
      final closeIcon = find.descendant(
        of: clearDate,
        matching: find.byIcon(AppIcons.close),
      );
      await tester.tap(closeIcon);
      await tester.pumpAndSettle();
      expect(result('today'), findsOneWidget);
      expect(clearDate, findsNothing);
      expect(tester.getRect(dateButton), buttonRect);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('search media downloads a video only after it is selected', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('naru-search-video-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      directory.deleteSync(recursive: true);
    });
    int requests = 0;
    await openSearch(
      tester,
      ChatConversationView(
        initialMessages: const [],
        onLoadSearchPage: ({beforeMessageId}) async => ChatConversationPage(
          hasMore: false,
          messages: [
            ChatMessage(
              id: 'remote-video',
              senderId: '2',
              recipientId: '1',
              content: '',
              createdAt: DateTime(2026),
              videoAttachment: const ChatVideoAttachment(
                assetId: 'remote-video',
                mediaAssetId: 'remote-video',
                width: 100,
                height: 100,
                duration: Duration(seconds: 12),
              ),
            ),
          ],
        ),
        onCreateMediaAssetAccessUrl: ({required mediaAssetId}) async {
          requests++;
          throw StateError('offline');
        },
      ),
    );
    await tab(tester, 'media');
    expect(requests, 0);
    await tester.runAsync(() async {
      await tester.tap(
        find.byKey(const ValueKey('search-media-remote-video:attachment')),
      );
      final timeout = Stopwatch()..start();
      while (requests == 0 && timeout.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        await tester.pump();
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late history response cannot reopen a closed search', (
    tester,
  ) async {
    final pending = Completer<ChatConversationPage>();
    await openSearch(
      tester,
      ChatConversationView(
        initialMessages: const [],
        onLoadSearchPage: ({beforeMessageId}) => pending.future,
      ),
    );
    await tester.tap(find.byTooltip('Close search'));
    await tester.pump();
    pending.complete(
      ChatConversationPage(
        messages: [fileMessage('late', 'late.pdf')],
        hasMore: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-search-top-bar')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'every link in a message opens through the existing link callback',
    (tester) async {
      Uri? opened;
      await openSearch(
        tester,
        ChatConversationView(
          initialMessages: [
            ChatMessage(
              id: 'link',
              senderId: '2',
              recipientId: '1',
              content: 'https://one.test/a https://two.test/b',
              createdAt: DateTime(2026),
            ),
          ],
          onOpenLink: (uri) async {
            opened = uri;
            return true;
          },
        ),
      );
      await tab(tester, 'links');
      await tester.tap(
        find.byKey(const ValueKey('search-card-link:https://two.test/b')),
      );
      await tester.pump();
      expect(opened, Uri.parse('https://two.test/b'));
    },
  );
  testWidgets('media filters and narrow layouts use each attachment once', (
    tester,
  ) async {
    await openSearch(
      tester,
      ChatConversationView(
        initialMessages: const [],
        onLoadSearchPage: ({beforeMessageId}) async => ChatConversationPage(
          hasMore: false,
          messages: [
            ChatMessage(
              id: 'photo',
              senderId: '2',
              recipientId: '1',
              content: '',
              createdAt: DateTime(2026),
              photoAttachments: const [
                ChatPhotoAttachment(
                  assetId: 'p1',
                  width: 100,
                  height: 100,
                  fileName: 'one.jpg',
                ),
                ChatPhotoAttachment(
                  assetId: 'p2',
                  width: 100,
                  height: 100,
                  fileName: 'two.jpg',
                ),
              ],
            ),
            ChatMessage(
              id: 'video',
              senderId: '2',
              recipientId: '1',
              content: '',
              createdAt: DateTime(2026),
              videoAttachment: const ChatVideoAttachment(
                assetId: 'v',
                width: 100,
                height: 100,
                duration: Duration(seconds: 12),
                fileName: 'clip.mp4',
              ),
            ),
          ],
        ),
      ),
      size: const Size(320, 640),
    );
    await tab(tester, 'media');
    expect(find.byKey(const ValueKey('search-media-photo:0')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-media-photo:1')), findsOneWidget);
    await tester.tap(find.text('Photos'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('search-media-video:attachment')),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Videos'));
    await tester.tap(find.text('Videos'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('search-media-video:attachment')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('search-media-photo:0')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
