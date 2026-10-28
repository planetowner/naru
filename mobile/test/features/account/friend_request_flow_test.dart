import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naru/core/l10n/app_strings.dart';
import 'package:naru/core/notifications/notification_service.dart';
import 'package:naru/design_system/app_icons.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/design_system/components/components.dart';
import 'package:naru/features/account/domain/friend_request.dart';
import 'package:naru/features/account/presentation/friend_request_card.dart';
import 'package:naru/features/auth/domain/app_language.dart';
import 'package:naru/features/auth/domain/app_user.dart';
import 'package:naru/features/auth/domain/auth_session.dart';
import 'package:naru/features/chat/data/chat_message_cache.dart';
import 'package:naru/features/chat/data/chat_realtime_service.dart';
import 'package:naru/features/chat/presentation/chat_conversation_screen.dart';
import '../../support/localized_test_app.dart';
import '../../support/load_app_fonts.dart';
import '../../support/pump_real_async_until.dart';
import 'account_api_test.dart' show apiFor, jsonResponse, user;

const me = AppUser(
  id: 'me',
  username: 'june',
  displayName: 'June',
  preferredLanguage: 'en',
);
const session = AuthSession(
  accessToken: 'token',
  refreshToken: 'refresh',
  tokenType: 'bearer',
  user: me,
);

final class FriendFlow {
  final controller = ChatConversationHomeController();
  List<Map<String, Object?>> inbox = [];
  List<AppUser> friends = [];
  final decisions = <String>[];
  int responseStatus = 204;
  late ChatRealtimeService realtime;
  final captureKey = GlobalKey();

  Map<String, Object?> request(String id) => {
    'id': id,
    'sender': user.toJson(),
  };

  Future<void> pump(WidgetTester tester, {Uri? socketUri}) async {
    final api = apiFor((request) async {
      switch (request.url.path) {
        case '/users':
          return jsonResponse(friends.map((u) => u.toJson()).toList());
        case '/users/friend-requests':
          return jsonResponse(inbox);
        case '/messages/conversation/maya':
          return jsonResponse([]);
        case '/messages/unread-counts':
          return jsonResponse({
            'counts_by_sender_id': {},
            'total_unread_count': 0,
          });
        default:
          if (request.url.path.endsWith('/respond')) {
            final id = request.url.path.split('/')[3];
            final decision = jsonDecode(request.body)['decision'] as String;
            decisions.add('$id:$decision');
            if (responseStatus == 204) {
              inbox = inbox.where((r) => r['id'] != id).toList();
              if (decision == 'accept') friends = [user];
            }
            return http.Response('', responseStatus);
          }
          throw StateError('${request.method} ${request.url}');
      }
    });
    realtime = ChatRealtimeService(
      chatApi: api,
      baseUri: socketUri ?? Uri.parse('https://api.test'),
      session: session,
      notificationService: NotificationService(),
    );
    addTearDown(realtime.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: AppTheme.light,
        builder: (context, child) => RepaintBoundary(
          key: captureKey,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: 44, bottom: 34)),
            child: child!,
          ),
        ),
        home: ChatConversationHomeScreen(
          chatApi: api,
          realtimeService: realtime,
          session: session,
          controller: controller,
          onProfileUpdated: (_) async {},
          messageCache: ChatMessageCache(
            chatApi: api,
            currentUserId: me.id,
            persistenceEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'pending inbox shows card; accept adds friend, decline leaves list unchanged',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final flow = FriendFlow();
      flow.inbox = [flow.request('one'), flow.request('two')];
      await flow.pump(tester);
      expect(find.byType(FriendRequestCard), findsOneWidget);
      expect(find.text('@Maya'), findsOneWidget);
      expect(
        tester.widget<AppProfileImage>(find.byType(AppProfileImage)).size,
        112,
      );
      expect(
        tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color!.a,
        closeTo(.24, .01),
      );
      await capture(tester, flow.captureKey);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(flow.decisions, ['one:accept']);
      expect(flow.friends, [user]);
      expect(
        tester
            .widget<FriendRequestCard>(find.byType(FriendRequestCard))
            .request
            .id,
        'two',
      );
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(flow.decisions, ['one:accept', 'two:decline']);
      expect(flow.friends, [user]);
      expect(find.byType(FriendRequestCard), findsNothing);
      expect(find.text('@Maya'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed response stays retryable and another device resolution removes stale card',
    (tester) async {
      final flow = FriendFlow();
      flow.inbox = [flow.request('one')];
      flow.responseStatus = 500;
      await flow.pump(tester);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(find.text(stringsForLanguage('en').requestFailed), findsOneWidget);
      expect(flow.inbox, hasLength(1));
      flow.responseStatus = 409;
      flow.inbox = [];
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(find.byType(FriendRequestCard), findsNothing);
      expect(flow.friends, isEmpty);
    },
  );

  testWidgets(
    'notification opens the pending request on chat list from settings',
    (tester) async {
      final flow = FriendFlow();
      await flow.pump(tester);
      await tester.tap(find.byIcon(AppIcons.settings));
      await tester.pumpAndSettle();
      flow.inbox = [flow.request('old'), flow.request('target')];
      flow.controller.openNotification({
        'type': 'friend_request',
        'request_id': 'target',
        'sender_id': user.id,
      });
      await tester.pumpAndSettle();
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(
        tester
            .widget<FriendRequestCard>(find.byType(FriendRequestCard))
            .request
            .id,
        'target',
      );
      expect(flow.controller.pendingUserId, isNull);
    },
  );

  test('message notifications retain conversation routing', () {
    final controller = ChatConversationHomeController();
    addTearDown(controller.dispose);
    controller.openNotification({'sender_id': 'maya', 'message_id': 'message'});
    expect(controller.pendingUserId, 'maya');
    expect(controller.pendingFriendRequestId, isNull);
  });

  testWidgets(
    'shared realtime events refresh requests and both parties friend lists',
    (tester) async {
      late HttpServer server;
      WebSocket? socket;
      await tester.runAsync(() async {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          socket = await WebSocketTransformer.upgrade(request);
          socket!.add(jsonEncode({'type': 'connected'}));
        });
      });
      final flow = FriendFlow();
      await flow.pump(
        tester,
        socketUri: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      await tester.runAsync(() async {
        flow.realtime.start();
      });
      await pumpRealAsyncUntil(
        tester,
        () => socket != null,
        failureReason: 'WebSocket should connect',
      );
      flow.inbox = [flow.request('one')];
      socket!.add(jsonEncode({'type': 'friends.changed'}));
      await pumpRealAsyncUntil(
        tester,
        () => find.byType(FriendRequestCard).evaluate().isNotEmpty,
        failureReason: 'Incoming request must show without reopening the app',
      );
      flow.inbox = [];
      flow.friends = [user];
      socket!.add(jsonEncode({'type': 'friends.changed'}));
      await pumpRealAsyncUntil(
        tester,
        () => find.byType(FriendRequestCard).evaluate().isEmpty,
        failureReason: 'Resolved request must disappear',
      );
      await tester.pumpAndSettle();
      expect(find.text('@Maya'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      flow.realtime.dispose();
      await tester.runAsync(() async {
        await socket?.close();
        await server.close(force: true);
      });
    },
  );

  testWidgets(
    'card uses localized shared controls in all eight languages on a small screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final language in AppLanguage.values) {
        await tester.pumpWidget(
          LocalizedTestApp(
            language: language.code,
            theme: AppTheme.light,
            home: Scaffold(
              body: FriendRequestCard(
                key: ValueKey(language),
                request: const FriendRequest(id: 'request', sender: user),
                onRespond: (_) async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final strings = stringsForLanguage(language.code);
        expect(find.text(strings.friendRequest), findsOneWidget);
        expect(find.text(strings.accept), findsOneWidget);
        expect(find.text(strings.decline), findsOneWidget);
        expect(tester.takeException(), isNull, reason: language.code);
      }
    },
  );

  testWidgets(
    'response buttons disable together while one request is in flight',
    (tester) async {
      final done = Completer<void>();
      int count = 0;
      await tester.pumpWidget(
        LocalizedTestApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: FriendRequestCard(
              request: const FriendRequest(id: 'request', sender: user),
              onRespond: (_) {
                count++;
                return done.future;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(
        tester
            .widgetList<AppButton>(find.byType(AppButton))
            .every((b) => b.onPressed == null),
        isTrue,
      );
      await tester.tap(find.text('Decline'));
      expect(count, 1);
      done.complete();
      await tester.pumpAndSettle();
    },
  );
}

Future<void> capture(WidgetTester tester, GlobalKey key) async {
  if (!const bool.fromEnvironment('CAPTURE_ACCOUNT_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/private/tmp/naru-friend-request-app.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
