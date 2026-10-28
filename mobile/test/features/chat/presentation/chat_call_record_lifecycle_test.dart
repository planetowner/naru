import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/features/chat/domain/chat_message.dart';
import 'package:naru/features/chat/presentation/chat_conversation_view.dart';

Future<void> _startCall(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Call'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Voice Call'));
  await tester.pumpAndSettle();
}

void _expectRecords(WidgetTester tester, String outcome) {
  expect(find.text('Voice Call'), findsOneWidget);
  expect(find.text(outcome), findsOneWidget);
  expect(
    tester.getTopLeft(find.text('Voice Call')).dy,
    lessThan(tester.getTopLeft(find.text(outcome)).dy),
  );
}

void main() {
  for (final incoming in [false, true]) {
    testWidgets(
      'reloaded ${incoming ? 'incoming' : 'outgoing'} ended call shows both records',
      (tester) async {
        final time = DateTime(2026, 10, 27, 12);
        await tester.pumpWidget(
          MaterialApp(
            home: ChatConversationView(
              currentUserName: 'Me',
              otherParticipantName: 'Lia',

              initialMessages: [
                for (final outcome in [
                  ChatCallOutcome.started,
                  ChatCallOutcome.ended,
                ])
                  ChatMessage(
                    id: outcome.name,
                    senderId: incoming ? '2' : '1',
                    recipientId: incoming ? '1' : '2',
                    content: '',
                    createdAt: outcome == ChatCallOutcome.started
                        ? time
                        : time.add(const Duration(seconds: 34)),
                    callAttachment: ChatCallAttachment(
                      kind: ChatCallKind.voice,
                      outcome: outcome,
                      duration: outcome == ChatCallOutcome.ended
                          ? const Duration(seconds: 34)
                          : Duration.zero,
                    ),
                  ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        _expectRecords(tester, 'End voice call');
        expect(find.text('00:34'), findsOneWidget);
      },
    );
  }

  for (final timeout in [false, true]) {
    testWidgets(
      'local call keeps start and ${timeout ? 'timeout' : 'cancel'} records',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ChatConversationView(
              currentUserName: 'Me',
              otherParticipantName: 'Lia',
              initialMessages: [],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _startCall(tester);
        if (timeout) {
          await tester.pump(const Duration(seconds: 31));
        } else {
          await tester.tap(find.byTooltip('End call'));
        }
        await tester.pumpAndSettle();
        _expectRecords(tester, timeout ? 'No Answer' : 'Canceled');
      },
    );
  }

  testWidgets(
    'ending before start save completes adds the server result once',
    (tester) async {
      final pendingStart = Completer<ChatMessage>();
      final start = ChatMessage(
        id: 'call-start',
        senderId: '1',
        recipientId: '2',
        content: '',
        createdAt: DateTime(2026, 10, 27, 12),
        callAttachment: const ChatCallAttachment(
          kind: ChatCallKind.voice,
          outcome: ChatCallOutcome.started,
          duration: Duration.zero,
        ),
      );
      var resultRequests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatConversationView(
            currentUserName: 'Me',
            otherParticipantName: 'Lia',

            initialMessages: const [],
            onSendCallMessage: ({required call}) => pendingStart.future,
            onUpdateCallOutcome:
                ({
                  required messageId,
                  required outcome,
                  required duration,
                }) async {
                  resultRequests++;
                  expect(messageId, start.id);
                  expect(outcome, ChatCallOutcome.cancelled);
                  return ChatMessage(
                    id: 'call-result',
                    senderId: start.senderId,
                    recipientId: start.recipientId,
                    content: '',
                    createdAt: start.createdAt.add(const Duration(seconds: 3)),
                    callAttachment: ChatCallAttachment(
                      kind: ChatCallKind.voice,
                      outcome: outcome,
                      duration: duration,
                    ),
                  );
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _startCall(tester);
      await tester.tap(find.byTooltip('End call'));
      await tester.pumpAndSettle();
      expect(resultRequests, 0);
      pendingStart.complete(start);
      await tester.pumpAndSettle();
      expect(resultRequests, 1);
      _expectRecords(tester, 'Canceled');
    },
  );
}
