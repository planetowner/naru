import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naru/design_system/app_colors.dart';
import 'package:naru/design_system/app_icons.dart';
import 'package:naru/design_system/app_typography.dart';
import 'package:naru/features/chat/domain/chat_message.dart';
import 'package:naru/features/chat/presentation/chat_conversation_view.dart';

final class _ControlledFilePicker extends FilePicker {
  final Completer<FilePickerResult?> selection = Completer<FilePickerResult?>();
  bool? allowsMultiple;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) {
    allowsMultiple = allowMultiple;
    return selection.future;
  }
}

Future<void> _openFilePicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('message-attachment')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
}

FilePickerResult _selectedFiles() {
  return FilePickerResult(<PlatformFile>[
    PlatformFile(name: 'first.pdf', size: 2, bytes: Uint8List.fromList([1, 2])),
    PlatformFile(
      name: 'second.m4a',
      size: 3,
      bytes: Uint8List.fromList([3, 4, 5]),
    ),
  ]);
}

ChatMessage _sentFileMessage(ChatFileAttachment file, int index) {
  return ChatMessage(
    id: 'sent-file-$index',
    senderId: '1',
    recipientId: '2',
    content: '',
    createdAt: DateTime(2026, 9, 6, 12, 0, index),
    fileAttachment: file,
  );
}

Widget _buildFileMessageScreen(ChatMessage message) {
  return MaterialApp(
    home: ChatConversationView(initialMessages: <ChatMessage>[message]),
  );
}

ChatMessage _fileMessage({
  required String senderId,
  required String recipientId,
}) {
  return ChatMessage(
    id: '1',
    senderId: senderId,
    recipientId: recipientId,
    content: '',
    createdAt: DateTime(2026, 7, 1, 12, 52),
    fileAttachment: const ChatFileAttachment(
      name: 'Report_v2.bin',
      sizeBytes: 350 * 1024,
    ),
  );
}

void main() {
  testWidgets('waits for confirmation and sends all selected files in order', (
    WidgetTester tester,
  ) async {
    final _ControlledFilePicker picker = _ControlledFilePicker();
    FilePicker.platform = picker;
    final List<ChatFileAttachment> sentFiles = <ChatFileAttachment>[];
    final Completer<ChatMessage> firstUpload = Completer<ChatMessage>();

    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationView(
          initialMessages: const <ChatMessage>[],
          onSendFileMessage: ({required file, replyTo}) {
            sentFiles.add(file);
            return sentFiles.length == 1
                ? firstUpload.future
                : Future<ChatMessage>.value(_sentFileMessage(file, 2));
          },
        ),
      ),
    );
    await _openFilePicker(tester);

    expect(picker.allowsMultiple, isTrue);
    expect(sentFiles, isEmpty);

    picker.selection.complete(_selectedFiles());
    await tester.pumpAndSettle();
    expect(sentFiles.map((file) => file.name), ['first.pdf']);

    firstUpload.complete(_sentFileMessage(sentFiles.first, 1));
    await tester.pumpAndSettle();

    expect(sentFiles.map((file) => file.name), ['first.pdf', 'second.m4a']);
    expect(sentFiles.map((file) => file.sizeBytes), [2, 3]);
    expect(sentFiles.first.uploadBytes, [1, 2]);
    expect(sentFiles.last.uploadBytes, [3, 4, 5]);
    expect(find.text('first.pdf'), findsOneWidget);
    expect(find.text('second.m4a'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('attachment-panel')),
      findsNothing,
    );
  });

  testWidgets('cancelling the file picker sends nothing', (
    WidgetTester tester,
  ) async {
    final _ControlledFilePicker picker = _ControlledFilePicker();
    FilePicker.platform = picker;
    int sendCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationView(
          initialMessages: const <ChatMessage>[],
          onSendFileMessage: ({required file, replyTo}) async {
            return _sentFileMessage(file, ++sendCount);
          },
        ),
      ),
    );
    await _openFilePicker(tester);
    picker.selection.complete(null);
    await tester.pumpAndSettle();

    expect(sendCount, 0);
  });

  testWidgets('keeps sent files visible when a later upload fails', (
    WidgetTester tester,
  ) async {
    final _ControlledFilePicker picker = _ControlledFilePicker();
    FilePicker.platform = picker;
    int sendCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatConversationView(
          initialMessages: const <ChatMessage>[],
          onSendFileMessage: ({required file, replyTo}) async {
            if (++sendCount == 2) {
              throw StateError('Upload failed');
            }
            return _sentFileMessage(file, sendCount);
          },
        ),
      ),
    );
    await _openFilePicker(tester);
    picker.selection.complete(_selectedFiles());
    await tester.pumpAndSettle();

    expect(sendCount, 2);
    expect(find.text('first.pdf'), findsOneWidget);
    expect(find.text('second.m4a'), findsNothing);
    expect(find.text('File sending failed.'), findsOneWidget);
  });

  for (final fromSearch in [false, true]) {
    testWidgets(
      'reopens an iOS attachment from ${fromSearch ? 'search' : 'chat'} after its previous access URL expires',
      (WidgetTester tester) async {
        const MethodChannel previewChannel = MethodChannel('naru/media-file');
        const MethodChannel pathChannel = MethodChannel(
          'plugins.flutter.io/path_provider',
        );
        final Directory temporaryDirectory = Directory.systemTemp
            .createTempSync('naru-file-preview-test-');
        final List<MethodCall> previewCalls = <MethodCall>[];
        final List<MethodCall> clipboardCalls = <MethodCall>[];
        final List<Uri> downloadUrls = <Uri>[];
        int accessUrlRequests = 0;
        bool firstUrlExpired = false;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          pathChannel,
          (_) async => temporaryDirectory.path,
        );
        messenger.setMockMethodCallHandler(previewChannel, (
          MethodCall call,
        ) async {
          previewCalls.add(call);
          return null;
        });
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboardCalls.add(call);
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(previewChannel, null);
          messenger.setMockMethodCallHandler(pathChannel, null);
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
          temporaryDirectory.deleteSync(recursive: true);
        });

        const ChatFileAttachment attachment = ChatFileAttachment(
          name: '수업 자료.pdf',
          sizeBytes: 3,
          mediaAssetId: 'file-asset',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ChatConversationView(
              initialMessages: [_sentFileMessage(attachment, 1)],
              onCreateMediaAssetAccessUrl: ({required mediaAssetId}) async {
                expect(mediaAssetId, 'file-asset');
                return Uri.parse(
                  'https://files.example.test/attachment?version=${++accessUrlRequests}',
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (fromSearch) {
          await tester.tap(find.byTooltip('Search'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('chat-search-tab-files')));
          await tester.pumpAndSettle();
        }
        for (int attempt = 1; attempt <= 2; attempt++) {
          await tester.runAsync(
            () => http.runWithClient(
              () async {
                await tester.tap(
                  fromSearch
                      ? find.descendant(
                          of: find.byKey(
                            const ValueKey('chat-search-files-results'),
                          ),
                          matching: find.text(attachment.name),
                        )
                      : find.text(attachment.name),
                );
                final Stopwatch timeout = Stopwatch()..start();
                while (previewCalls.length < attempt &&
                    find
                        .text('The file could not be opened.')
                        .evaluate()
                        .isEmpty &&
                    timeout.elapsed < const Duration(seconds: 5)) {
                  await Future<void>.delayed(const Duration(milliseconds: 1));
                  await tester.pump();
                }
              },
              () => MockClient((request) async {
                downloadUrls.add(request.url);
                if (firstUrlExpired &&
                    request.url.queryParameters['version'] == '1') {
                  return http.Response('Request has expired', 403);
                }
                return http.Response.bytes([10, 20, 30], 200);
              }),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            downloadUrls.last.queryParameters['version'],
            '$attempt',
            reason:
                'Reopening must request a new URL instead of downloading with the expired one.',
          );
          expect(previewCalls.length, attempt);
          expect(find.text('The file could not be opened.'), findsNothing);
          firstUrlExpired = true;
          await tester.pump(const Duration(minutes: 16));
        }

        expect(previewCalls.map((call) => call.method), [
          'preview-file',
          'preview-file',
        ]);
        final String path =
            (previewCalls.last.arguments as Map)['path'] as String;
        expect(path, endsWith('/naru-files/file-asset/수업 자료.pdf'));
        expect(File(path).readAsBytesSync(), [10, 20, 30]);
        expect(clipboardCalls, isEmpty);
        expect(find.text('File downloaded. Path copied.'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets('outgoing file messages match the outgoing bubble tone', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildFileMessageScreen(_fileMessage(senderId: '1', recipientId: '2')),
    );
    await tester.pumpAndSettle();

    final Finder bubbleFinder = find.byKey(
      const ValueKey<String>('outgoing-bubble-1'),
    );

    expect(bubbleFinder, findsOneWidget);
    expect(
      find.descendant(of: bubbleFinder, matching: find.text('Report_v2.bin')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bubbleFinder, matching: find.text('350 KB')),
      findsOneWidget,
    );

    final Text title = tester.widget<Text>(find.text('Report_v2.bin'));
    final Text metadata = tester.widget<Text>(find.text('350 KB'));
    final Icon icon = tester.widget<Icon>(
      find.descendant(of: bubbleFinder, matching: find.byIcon(AppIcons.file)),
    );

    expect(title.style?.color, AppColors.white);
    expect(title.style?.fontSize, AppTypography.typography6.fontSize);
    expect(title.style?.fontWeight, AppTypography.regular);
    expect(metadata.style?.color, AppColors.white.withAlpha(200));
    expect(icon.color, AppColors.white);

    await tester.tap(find.text('Report_v2.bin'));
    await tester.pump();

    expect(find.text('File preview is not available yet.'), findsOneWidget);
  });

  testWidgets(
    'incoming file messages use incoming colors without translation',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildFileMessageScreen(_fileMessage(senderId: '2', recipientId: '1')),
      );
      await tester.pumpAndSettle();

      final Finder bubbleFinder = find.byKey(
        const ValueKey<String>('incoming-bubble-1'),
      );

      expect(bubbleFinder, findsOneWidget);
      expect(
        find.descendant(of: bubbleFinder, matching: find.text('Report_v2.bin')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bubbleFinder, matching: find.text('350 KB')),
        findsOneWidget,
      );

      final Text title = tester.widget<Text>(find.text('Report_v2.bin'));
      final Text metadata = tester.widget<Text>(find.text('350 KB'));
      final Icon icon = tester.widget<Icon>(
        find.descendant(of: bubbleFinder, matching: find.byIcon(AppIcons.file)),
      );

      expect(title.style?.color, AppColors.grey900);
      expect(title.style?.fontSize, AppTypography.typography6.fontSize);
      expect(title.style?.fontWeight, AppTypography.regular);
      expect(metadata.style?.color, AppColors.grey500);
      expect(icon.color, AppColors.blue500);

      await tester.tap(find.text('Report_v2.bin'));
      await tester.pump();

      expect(find.text('File preview is not available yet.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
