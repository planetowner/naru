import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/features/chat/domain/chat_message.dart';
import 'package:naru/features/chat/presentation/chat_conversation_view.dart';

final Uint8List _photoBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABmJLR0QA'
  '/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gMQ'
  'FwcdLl4wmwAAAAtJREFUCNdjYAACAAAFAAHiJgWbAAAAAElFTkSuQmCC',
);

void main() {
  for (final isPhoto in [false, true]) {
    for (final isOutgoing in [false, true]) {
      testWidgets(
        '${isOutgoing ? 'outgoing' : 'incoming'} '
        '${isPhoto ? 'photo' : 'bubble'} preserves its reply highlight motion',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(420, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final String senderId = isOutgoing ? '1' : '2';
          final ChatMessage original = ChatMessage(
            id: 'original',
            senderId: senderId,
            recipientId: isOutgoing ? '2' : '1',
            content: isPhoto ? '' : 'Original message',
            createdAt: DateTime(2026, 7, 1, 12),
            photoAttachments: isPhoto
                ? [
                    ChatPhotoAttachment(
                      assetId: 'highlight-photo',
                      previewBytes: _photoBytes,
                      width: 1200,
                      height: 900,
                    ),
                  ]
                : const [],
          );
          await tester.pumpWidget(
            MaterialApp(
              home: ChatConversationView(
                currentUserName: 'Me',
                otherParticipantName: 'Lia',

                initialMessages: [
                  original,
                  ChatMessage(
                    id: 'reply',
                    senderId: '1',
                    recipientId: '2',
                    content: 'Reply',
                    createdAt: DateTime(2026, 7, 1, 12, 1),
                    replyTo: ChatReplyReference(
                      messageId: original.id,
                      senderId: senderId,
                      content: isPhoto ? 'Photo' : original.content,
                    ),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          final String presentationId = isPhoto && isOutgoing
              ? 'photo-highlight-photo'
              : original.id;
          final Finder pulse = find.byKey(
            ValueKey<String>('message-pulse-$presentationId'),
          );
          final Finder highlight = find.byKey(
            ValueKey<String>('message-highlight-$presentationId'),
          );

          final Finder quote = find.byKey(
            const ValueKey<String>('reply-quote-area-reply'),
          );
          final double initialReplyTop = tester.getTopLeft(quote).dy;
          await tester.tap(quote);
          for (
            int frame = 0;
            frame < 30 && highlight.evaluate().isEmpty;
            frame++
          ) {
            await tester.pump();
          }
          expect(highlight, findsOneWidget);
          await tester.pump();

          // 공통화 전 0·40·100·180·360ms에서 측정한 확대율과 세로 이동량이에요.
          for (final (delta, expectedScale, photoY, bubbleY)
              in <(int, double, double, double)>[
                (0, 1, 0, 0),
                (
                  40,
                  1.0228446476633848,
                  -0.7070707070707071,
                  -1.23009641264379,
                ),
                (
                  60,
                  1.0241780861887335,
                  -1.007936507936508,
                  -1.2883343147933481,
                ),
                (80, 0.995, 0.5, 0.5),
                (180, 1, 0, 0),
              ]) {
            await tester.pump(Duration(milliseconds: delta));
            final Transform scale = tester.widget<Transform>(pulse);
            final Transform translation = tester.widget<Transform>(
              find.ancestor(of: pulse, matching: find.byType(Transform)).first,
            );
            expect(scale.transform.storage[0], closeTo(expectedScale, 1e-9));
            expect(
              translation.transform.storage[13],
              closeTo(isPhoto ? photoY : bubbleY, 1e-9),
            );
            expect(
              scale.alignment,
              isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
            );
          }
          await tester.pump(const Duration(milliseconds: 81));
          expect(highlight, findsNothing);
          final Finder backButton = find.byKey(
            const ValueKey<String>('back-to-reply-message'),
          );
          expect(backButton, findsOneWidget);
          await tester.tap(backButton);
          await tester.pumpAndSettle();
          expect(backButton, findsNothing);
          expect(tester.getTopLeft(quote).dy, closeTo(initialReplyTop, 1));
        },
      );
    }
  }
}
