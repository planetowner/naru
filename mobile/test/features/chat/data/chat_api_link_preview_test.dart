import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naru/features/chat/data/chat_api.dart';
import 'package:naru/features/chat/data/chat_message_cache.dart';
import 'package:naru/features/chat/data/device_link_preview_fetcher.dart';
import 'package:naru/features/chat/domain/chat_message.dart';

const String _fmkoreaUrl = 'https://m.fmkorea.com/10166678809';
const String _fmkoreaCanonicalUrl = 'https://www.fmkorea.com/10166678809';
const String _fmkoreaImageUrl = 'https://image.fmkorea.com/files/preview.jpg';

http.Response _createdMessageResponse(
  http.Request request,
  Map<String, dynamic> requestBody,
) {
  return http.Response(
    jsonEncode(<String, Object?>{
      'id': 'message-1',
      'sender_id': 'current-user',
      'recipient_id': requestBody['recipient_id'],
      'content': requestBody['content'],
      'message_type': requestBody['message_type'],
      'metadata': {
        ...?(requestBody['metadata'] as Map<String, dynamic>?),
        'language': 'en',
      },
      'created_at': '2026-08-03T10:00:00Z',
      'edited_at': null,
      'read_at': null,
      'translation_status': 'none',
      'translated_content': null,
      'source_language': null,
      'translated_language': null,
      'reply_to': null,
    }),
    201,
    headers: const <String, String>{'content-type': 'application/json'},
    request: request,
  );
}

Map<String, dynamic> _receivedLink({
  String? language,
  String title = '한국어 제목',
}) => {
  'id': '33333333-3333-4333-8333-333333333333',
  'sender_id': '11111111-1111-4111-8111-111111111111',
  'recipient_id': '22222222-2222-4222-8222-222222222222',
  'content': 'https://example.com/article',
  'message_type': 'link',
  'metadata': <String, dynamic>{
    'url': 'https://example.com/article',
    'language': language,
    'title': title,
  },
  'created_at': '2026-10-28T10:00:00Z',
  'translation_status': 'none',
};

ChatApi _api(http.Client client, String language) => ChatApi(
  client: client,
  baseUri: Uri.parse('https://api.example.com'),
  accessToken: 'test-token',
  preferredLanguage: language,
);

void main() {
  for (final language in ['ko', 'ja', 'zh-CN', 'en', 'es', 'fr', 'de', 'it']) {
    test(
      'receives and caches the viewer card in $language without mixing languages',
      () async {
        var requests = 0;
        final api = _api(
          MockClient((request) async {
            requests++;
            expect(
              request.url.path,
              '/messages/33333333-3333-4333-8333-333333333333/link-preview',
            );
            expect(request.headers['Authorization'], 'Bearer test-token');
            return http.Response(
              jsonEncode({
                'url': 'https://example.com/article',
                'title': 'Title $language',
                'language': language,
              }),
              200,
            );
          }),
          language,
        );
        final incoming = api.messageFromJson(
          _receivedLink(language: language == 'ko' ? 'es' : 'ko'),
        );
        expect(incoming.linkPreview?.title, isNull);
        final results = await api.resolveLinkPreviews([incoming, incoming]);
        expect(requests, 1);
        expect(results.first.linkPreview?.title, 'Title $language');
        expect(results.first.linkPreview?.language, language);
        final cached = api.messageFromJson(
          api.messageToCacheJson(results.first),
        );
        expect(cached.linkPreview?.title, 'Title $language');
        await api.resolveLinkPreview(cached);
        expect(requests, 1);
      },
    );

    test(
      'device requests $language using the same language code as the server',
      () async {
        final fetcher = DeviceLinkPreviewFetcher(
          client: MockClient((request) async {
            expect(request.headers['Accept-Language'], language);
            return http.Response(
              '<head><title>Title $language</title></head>',
              200,
              headers: {'content-type': 'text/html'},
              request: request,
            );
          }),
        );
        final result = await fetcher.fetch(
          Uri.parse(_fmkoreaUrl),
          language: language,
        );
        expect(result?['language'], language);
        expect(result?['title'], 'Title $language');
      },
    );
  }

  test(
    'uses an existing viewer variant without refetching the sender card',
    () async {
      final api = _api(
        MockClient((_) async => throw StateError('No request expected')),
        'es',
      );
      final json = _receivedLink(language: 'ko');
      (json['metadata'] as Map)['previews_by_language'] = {
        'es': {'language': 'es', 'url': json['content'], 'title': 'Hola'},
        'fr': {'language': 'fr', 'url': json['content'], 'title': 'Bonjour'},
      };
      final message = await api.resolveLinkPreview(api.messageFromJson(json));
      expect(message.linkPreview?.title, 'Hola');
    },
  );

  test('old disk cards are fetched in the current account language', () async {
    final directory = await Directory.systemTemp.createTemp(
      'naru-link-locale-',
    );
    addTearDown(() => directory.delete(recursive: true));
    var requests = 0;
    final api = _api(
      MockClient((_) async {
        requests++;
        return http.Response(
          jsonEncode({
            'language': 'es',
            'url': 'https://example.com/article',
            'title': 'Hola',
          }),
          200,
        );
      }),
      'es',
    );
    ChatMessageCache cache() => ChatMessageCache(
      chatApi: api,
      currentUserId: '22222222-2222-4222-8222-222222222222',
      directoryLoader: () async => directory,
    );
    final senderApi = _api(
      MockClient((_) async => throw StateError('No request expected')),
      'ko',
    );
    final oldMessage = senderApi.messageFromJson(_receivedLink(language: 'ko'));
    await cache().mergeLatestConversation(
      otherUserId: oldMessage.senderId,
      messages: [oldMessage],
      hasMoreOlder: false,
    );
    final result = await cache().readConversation(oldMessage.senderId);
    expect(result.messages.single.linkPreview?.title, 'Hola');
    expect(requests, 1);
  });

  test(
    'failed lookup keeps the original link without showing the sender language',
    () async {
      final api = _api(
        MockClient((_) async => throw http.ClientException('offline')),
        'es',
      );
      final message = await api.resolveLinkPreview(
        api.messageFromJson(_receivedLink(language: 'ko')),
      );
      expect(message.content, 'https://example.com/article');
      expect(message.linkPreview?.url, message.content);
      expect(message.linkPreview?.title, isNull);
    },
  );

  test(
    'recipient device fallback and message editing both use the account language',
    () async {
      final requests = <String>[];
      final api = _api(
        MockClient((request) async {
          requests.add('${request.method} ${request.url.host}');
          if (request.url.host == 'm.fmkorea.com') {
            expect(request.headers['Accept-Language'], 'es');
            return http.Response(
              '<head><title>Hola</title></head>',
              200,
              headers: {'content-type': 'text/html'},
              request: request,
            );
          }
          if (request.method == 'PATCH') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['metadata']['language'], 'es');
            expect(body['metadata']['title'], 'Hola');
            return http.Response(
              jsonEncode({
                ..._receivedLink(),
                'content': _fmkoreaUrl,
                'metadata': body['metadata'],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({'url': _fmkoreaUrl, 'language': 'es'}),
            200,
          );
        }),
        'es',
      );
      final incoming = {
        ..._receivedLink(language: 'ko'),
        'content': _fmkoreaUrl,
      };
      final received = await api.resolveLinkPreview(
        api.messageFromJson(incoming),
      );
      expect(received.linkPreview?.title, 'Hola');
      final edited = await api.editTextMessage(
        messageId: received.id,
        content: _fmkoreaUrl,
      );
      expect(edited.linkPreview?.title, 'Hola');
      expect(requests, [
        'GET api.example.com',
        'GET m.fmkorea.com',
        'PATCH api.example.com',
      ]);
    },
  );

  test('an empty cached server card still uses the device fallback', () async {
    var requests = 0;
    final api = _api(
      MockClient((request) async {
        requests++;
        expect(request.url.host, 'm.fmkorea.com');
        expect(request.headers['Accept-Language'], 'es');
        return http.Response(
          '<head><title>Hola</title></head>',
          200,
          headers: {'content-type': 'text/html'},
          request: request,
        );
      }),
      'es',
    );
    final json = {
      ..._receivedLink(),
      'content': _fmkoreaUrl,
      'metadata': {'url': _fmkoreaUrl, 'language': 'es'},
    };
    final card = await api.resolveLinkPreview(api.messageFromJson(json));
    expect(card.linkPreview?.title, 'Hola');
    expect(requests, 1);
  });

  test(
    'conversation and reply-context loading use the same viewer card',
    () async {
      var previewRequests = 0;
      final api = _api(
        MockClient((request) async {
          if (request.url.path.endsWith('/link-preview')) {
            previewRequests++;
            return http.Response(
              jsonEncode({
                'language': 'es',
                'url': 'https://example.com/article',
                'title': 'Hola',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(
              request.url.path.contains('/around/')
                  ? {
                      'messages': [_receivedLink(language: 'ko')],
                      'has_more_older': false,
                      'has_more_newer': false,
                    }
                  : [_receivedLink(language: 'ko')],
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        'es',
      );
      final page = await api.listConversation(otherUserId: 'other');
      final context = await api.getConversationMessageContext(
        otherUserId: 'other',
        messageId: page.messages.single.id,
      );
      expect(page.messages.single.linkPreview?.title, 'Hola');
      expect(context.messages.single.linkPreview?.title, 'Hola');
      expect(previewRequests, 1);
    },
  );

  test(
    'sends device-fetched FMKorea Open Graph metadata to the server',
    () async {
      var requestCount = 0;
      late Map<String, dynamic> sentMetadata;
      final MockClient client = MockClient((http.Request request) async {
        requestCount += 1;

        if (request.url.host == 'm.fmkorea.com') {
          expect(request.method, 'GET');
          expect(
            request.headers['User-Agent'],
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
            'Safari/605.1.15',
          );
          expect(request.headers['Accept'], 'text/html,application/xhtml+xml');
          expect(request.headers['Accept-Language'], 'en');

          return http.Response(
            '<html><head>'
            '<meta property="og:url" content="$_fmkoreaCanonicalUrl">'
            '<meta property="og:title" content="우리는 모르는 잘생긴 남자의 삶">'
            '<meta property="og:description" '
            'content="Tap here to open the link.">'
            '<meta property="og:image" content="$_fmkoreaImageUrl">'
            '<meta property="og:site_name" content="에펨코리아">'
            '</head><body></body></html>',
            200,
            headers: const <String, String>{
              'content-type': 'text/html; charset=UTF-8',
            },
            request: request,
          );
        }

        expect(request.method, 'POST');
        expect(request.url, Uri.parse('https://api.example.com/messages'));
        final Map<String, dynamic> requestBody =
            jsonDecode(request.body) as Map<String, dynamic>;
        sentMetadata = requestBody['metadata'] as Map<String, dynamic>;

        return _createdMessageResponse(request, requestBody);
      });
      final ChatApi chatApi = ChatApi(
        client: client,
        baseUri: Uri.parse('https://api.example.com'),
        accessToken: 'test-token',
        preferredLanguage: 'en',
      );

      final ChatMessage message = await chatApi.sendTextMessage(
        recipientId: 'other-user',
        content: _fmkoreaUrl,
      );

      expect(requestCount, 2);
      expect(sentMetadata, <String, dynamic>{
        'language': 'en',
        'url': _fmkoreaUrl,
        'canonical_url': _fmkoreaCanonicalUrl,
        'domain': 'm.fmkorea.com',
        'title': '우리는 모르는 잘생긴 남자의 삶',
        'description': 'Tap here to open the link.',
        'site_name': '에펨코리아',
        'image_url': _fmkoreaImageUrl,
      });
      expect(message.linkPreview?.title, '우리는 모르는 잘생긴 남자의 삶');
      expect(message.linkPreview?.imageUrl, _fmkoreaImageUrl);
    },
  );

  test(
    'still sends an FMKorea link when device fetching is rejected',
    () async {
      var requestCount = 0;
      final MockClient client = MockClient((http.Request request) async {
        requestCount += 1;

        if (request.url.host == 'm.fmkorea.com') {
          return http.Response('Too Many Requests', 429, request: request);
        }

        final Map<String, dynamic> requestBody =
            jsonDecode(request.body) as Map<String, dynamic>;

        return _createdMessageResponse(request, requestBody);
      });
      final ChatApi chatApi = ChatApi(
        client: client,
        baseUri: Uri.parse('https://api.example.com'),
        accessToken: 'test-token',
        preferredLanguage: 'en',
      );

      final ChatMessage message = await chatApi.sendTextMessage(
        recipientId: 'other-user',
        content: _fmkoreaUrl,
      );

      expect(requestCount, 2);
      expect(message.linkPreview?.domain, 'm.fmkorea.com');
      expect(message.linkPreview?.title, isNull);
    },
  );

  test('does not device-fetch domains handled by the server', () async {
    var requestCount = 0;
    final MockClient client = MockClient((http.Request request) async {
      requestCount += 1;
      expect(request.url, Uri.parse('https://api.example.com/messages'));
      final Map<String, dynamic> requestBody =
          jsonDecode(request.body) as Map<String, dynamic>;

      return _createdMessageResponse(request, requestBody);
    });
    final ChatApi chatApi = ChatApi(
      client: client,
      baseUri: Uri.parse('https://api.example.com'),
      accessToken: 'test-token',
      preferredLanguage: 'en',
    );

    await chatApi.sendTextMessage(
      recipientId: 'other-user',
      content: 'https://youtu.be/CS0zz7WlnV0',
    );

    expect(requestCount, 1);
  });
}
