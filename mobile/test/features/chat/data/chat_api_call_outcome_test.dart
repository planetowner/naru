import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naru/features/chat/data/chat_api.dart';
import 'package:naru/features/chat/domain/chat_message.dart';

Map<String, Object?> _record(String id, String outcome, int seconds) => {
  'id': id,
  'sender_id': 'caller',
  'recipient_id': 'recipient',
  'content': '',
  'message_type': 'call',
  'metadata': {
    'kind': 'voice',
    'outcome': outcome,
    'duration_ms': seconds * 1000,
  },
  'created_at': id == 'start' ? '2026-10-27T12:00:00Z' : '2026-10-27T12:00:34Z',
  'translation_status': 'none',
};

void main() {
  for (final outcome in {
    ChatCallOutcome.cancelled: 'cancelled',
    ChatCallOutcome.noAnswer: 'no_answer',
    ChatCallOutcome.ended: 'ended',
  }.entries) {
    test(
      '${outcome.value} response and reloaded history retain separate IDs',
      () async {
        final seconds = outcome.key == ChatCallOutcome.ended ? 34 : 0;
        final start = _record('start', 'started', 0);
        final result = _record('result', outcome.value, seconds);
        final api = ChatApi(
          baseUri: Uri.parse('https://api.example.test'),
          accessToken: 'test',
          preferredLanguage: 'en',
          client: MockClient((request) async {
            if (request.method == 'PATCH') {
              expect(request.url.path, '/messages/start/call-outcome');
              expect(jsonDecode(request.body), {
                'outcome': outcome.value,
                'duration_ms': seconds * 1000,
              });
              return http.Response(jsonEncode(result), 200);
            }
            expect(request.method, 'GET');
            expect(request.url.path, '/messages/conversation/recipient');
            return http.Response(jsonEncode([start, result]), 200);
          }),
        );
        final saved = await api.updateCallOutcome(
          messageId: 'start',
          outcome: outcome.key,
          duration: Duration(seconds: seconds),
        );
        expect(saved.id, 'result');
        expect(saved.callAttachment!.outcome, outcome.key);
        expect(saved.callAttachment!.duration, Duration(seconds: seconds));
        final reloaded = await api.listConversation(otherUserId: 'recipient');
        expect(reloaded.messages.map((m) => m.id), ['start', 'result']);
        expect(
          reloaded.messages.first.callAttachment!.outcome,
          ChatCallOutcome.started,
        );
        expect(reloaded.messages.last.callAttachment!.outcome, outcome.key);
        expect(
          reloaded.messages.last.createdAt.isAfter(
            reloaded.messages.first.createdAt,
          ),
          isTrue,
        );
      },
    );
  }
}
