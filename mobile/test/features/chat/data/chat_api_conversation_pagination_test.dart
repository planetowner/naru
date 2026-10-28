import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naru/features/chat/data/chat_api.dart';
import 'package:naru/features/chat/data/chat_api_exception.dart';

void main() {
  test('requests the page before the supplied message cursor', () async {
    final MockClient client = MockClient((http.Request request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/messages/conversation/other-user');
      expect(request.url.queryParameters, <String, String>{
        'limit': '100',
        'before_message_id': 'message-101',
      });

      return http.Response(
        '[]',
        200,
        headers: const <String, String>{
          'content-type': 'application/json',
          'x-has-more': 'true',
        },
      );
    });
    final ChatApi chatApi = ChatApi(
      client: client,
      baseUri: Uri.parse('https://api.example.com'),
      accessToken: 'test-token',
      preferredLanguage: 'en',
    );

    final ChatConversationPage page = await chatApi.listConversation(
      otherUserId: 'other-user',
      beforeMessageId: 'message-101',
    );

    expect(page.messages, isEmpty);
    expect(page.hasMore, isTrue);
  });

  test('uses the server pagination completion header', () async {
    final MockClient client = MockClient((http.Request request) async {
      return http.Response(
        '[]',
        200,
        headers: const <String, String>{
          'content-type': 'application/json',
          'x-has-more': 'false',
        },
      );
    });
    final ChatApi chatApi = ChatApi(
      client: client,
      baseUri: Uri.parse('https://api.example.com'),
      accessToken: 'test-token',
      preferredLanguage: 'en',
    );

    final ChatConversationPage page = await chatApi.listConversation(
      otherUserId: 'other-user',
    );

    expect(page.hasMore, isFalse);
  });

  test('requests the page after the supplied message cursor', () async {
    final MockClient client = MockClient((http.Request request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/messages/conversation/other-user');
      expect(request.url.queryParameters, <String, String>{
        'limit': '100',
        'after_message_id': 'message-101',
      });

      return http.Response(
        '[]',
        200,
        headers: const <String, String>{
          'content-type': 'application/json',
          'x-has-more': 'false',
        },
      );
    });
    final ChatApi chatApi = ChatApi(
      client: client,
      baseUri: Uri.parse('https://api.example.com'),
      accessToken: 'test-token',
      preferredLanguage: 'en',
    );

    final ChatConversationPage page = await chatApi.listConversation(
      otherUserId: 'other-user',
      afterMessageId: 'message-101',
    );

    expect(page.messages, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('requests a small message-centered conversation context', () async {
    final MockClient client = MockClient((http.Request request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/messages/conversation/other-user/around/message-101',
      );
      expect(request.url.queryParameters, <String, String>{
        'older_limit': '20',
        'newer_limit': '25',
      });

      return http.Response(
        '{"messages":[],"has_more_older":true,"has_more_newer":false}',
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    final ChatApi chatApi = ChatApi(
      client: client,
      baseUri: Uri.parse('https://api.example.com'),
      accessToken: 'test-token',
      preferredLanguage: 'en',
    );

    final ChatConversationContext context = await chatApi
        .getConversationMessageContext(
          otherUserId: 'other-user',
          messageId: 'message-101',
          olderLimit: 20,
          newerLimit: 25,
        );

    expect(context.messages, isEmpty);
    expect(context.hasMoreOlder, isTrue);
    expect(context.hasMoreNewer, isFalse);
  });

  for (final bool aroundMessage in <bool>[false, true]) {
    final String operation = aroundMessage
        ? 'Message context loading'
        : 'Conversation loading';

    Future<Object> load(ChatApi api) => aroundMessage
        ? api.getConversationMessageContext(
            otherUserId: 'other-user',
            messageId: 'message-101',
          )
        : api.listConversation(otherUserId: 'other-user');

    test('$operation marks only transient failures as retryable', () async {
      for (final int statusCode in <int>[429, 503, 401, 400]) {
        final ChatApi api = ChatApi(
          client: MockClient((_) async => http.Response('{}', statusCode)),
          baseUri: Uri.parse('https://api.example.com'),
          accessToken: 'test-token',
          preferredLanguage: 'en',
        );

        await expectLater(
          load(api),
          throwsA(
            isA<ChatApiException>()
                .having(
                  (ChatApiException error) => error.retryable,
                  'retryable',
                  statusCode == 429 || statusCode == 503,
                )
                .having(
                  (ChatApiException error) => error.statusCode,
                  'statusCode',
                  statusCode,
                )
                .having(
                  (ChatApiException error) => error.message,
                  'message',
                  '$operation failed with status code $statusCode.',
                ),
          ),
        );
      }
    });

    test('$operation preserves server error details', () async {
      final ChatApi api = ChatApi(
        client: MockClient(
          (_) async => http.Response('{"detail":"Message not found"}', 404),
        ),
        baseUri: Uri.parse('https://api.example.com'),
        accessToken: 'test-token',
        preferredLanguage: 'en',
      );

      await expectLater(
        load(api),
        throwsA(
          isA<ChatApiException>().having(
            (ChatApiException error) => error.message,
            'message',
            'Message not found',
          ),
        ),
      );
    });

    test('$operation keeps network failures retryable', () async {
      final ChatApi api = ChatApi(
        client: MockClient((_) async => throw http.ClientException('offline')),
        baseUri: Uri.parse('https://api.example.com'),
        accessToken: 'test-token',
        preferredLanguage: 'en',
      );

      await expectLater(
        load(api),
        throwsA(
          isA<ChatApiException>()
              .having(
                (ChatApiException error) => error.retryable,
                'retryable',
                true,
              )
              .having(
                (ChatApiException error) => error.message,
                'message',
                '$operation failed because of a network error.',
              ),
        ),
      );
    });
  }
}
