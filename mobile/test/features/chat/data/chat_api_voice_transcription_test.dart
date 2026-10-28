import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naru/features/chat/data/chat_api.dart';
import 'package:naru/features/chat/domain/chat_message.dart';
import 'package:naru/features/chat/domain/chat_search.dart';

Map<String, Object?> voiceJson({String? status = 'completed'}) => {
  'id': 'voice',
  'sender_id': '2',
  'recipient_id': '1',
  'message_type': 'voice_memo',
  'content': '你好',
  'created_at': '2026-10-27T19:30:00Z',
  'source_language': 'zh-CN',
  'translated_language': 'ko',
  'translated_content': '안녕하세요',
  'translation_status': 'completed',
  'transcription_status': ?status,
  'metadata': {
    'duration_ms': 12000,
    'media_asset_id': 'audio',
    'waveform_samples': [0.2, 0.8],
  },
};

void main() {
  ChatApi api(http.Client client) => ChatApi(
    baseUri: Uri.parse('https://api.example.com'),
    accessToken: 'test-token',
    client: client,
  );

  test(
    'voice original, translation and processing state survive cache serialization',
    () {
      final ChatApi client = api(
        MockClient((_) async => throw StateError('unexpected request')),
      );
      for (final String status in ['none', 'pending', 'completed', 'failed']) {
        final ChatMessage message = client.messageFromJson(
          voiceJson(status: status),
        );
        final ChatMessage cached = client.messageFromJson(
          client.messageToCacheJson(message),
        );
        expect(cached.transcriptionStatus, message.transcriptionStatus);
        expect(cached.content, '你好');
        expect(cached.translatedContent, '안녕하세요');
        expect(cached.translationStatus, ChatTranslationStatus.translated);
        expect(cached.voiceMemoAttachment!.waveformSamples, [0.2, 0.8]);
        expect(
          cached.copyWith(readAt: DateTime.now()).transcriptionStatus,
          message.transcriptionStatus,
        );
      }
      final ChatMessage completed = client.messageFromJson(voiceJson());
      expect(chatMessageMatchesQuery(completed, '你好'), isTrue);
      expect(chatMessageMatchesQuery(completed, '안녕'), isTrue);
      expect(
        client.messageFromJson(voiceJson(status: null)).transcriptionStatus,
        ChatTranscriptionStatus.none,
      );
    },
  );

  test(
    'transcription and translation retries use their own authorized endpoints',
    () async {
      final List<String> paths = [];
      final ChatApi client = api(
        MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode(voiceJson(status: 'pending')),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final ChatMessage pending = await client.retryMessageTranscription(
        messageId: 'voice',
      );
      expect(pending.transcriptionStatus, ChatTranscriptionStatus.transcribing);
      await client.retryMessageTranslation(messageId: 'voice');
      expect(paths, [
        '/messages/voice/transcription/retry',
        '/messages/voice/translation/retry',
      ]);
    },
  );
}
