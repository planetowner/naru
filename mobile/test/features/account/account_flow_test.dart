import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/core/notifications/notification_service.dart';
import 'package:naru/design_system/app_icons.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/design_system/components/components.dart';
import 'package:naru/features/auth/domain/app_user.dart';
import 'package:naru/features/auth/domain/auth_session.dart';
import 'package:naru/features/chat/data/chat_message_cache.dart';
import 'package:naru/features/chat/data/chat_realtime_service.dart';
import 'package:naru/features/chat/presentation/chat_conversation_screen.dart';

import '../../support/localized_test_app.dart';
import '../../support/load_app_fonts.dart';
import 'account_api_test.dart' show apiFor, jsonResponse, user;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('home opens friend and settings flows using shared controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    bool added = false;
    bool requested = false;
    const me = AppUser(
      id: 'june',
      username: 'june',
      displayName: 'June',
      preferredLanguage: 'en',
    );
    const session = AuthSession(
      accessToken: 'test',
      refreshToken: 'refresh',
      tokenType: 'bearer',
      user: me,
    );
    final api = apiFor((request) async {
      switch (request.url.path) {
        case '/users/friend-requests':
          return jsonResponse([]);
        case '/users':
          return jsonResponse(added ? [user.toJson()] : []);
        case '/users/search':
          return jsonResponse({
            'user': user.toJson(),
            'is_friend': added,
            'outgoing_request_id': requested ? 'request-1' : null,
          });
        case '/users/friends/maya':
          requested = true;
          return jsonResponse({
            'user': user.toJson(),
            'is_friend': false,
            'outgoing_request_id': 'request-1',
          });
        case '/messages/conversation/maya':
          return jsonResponse([]);
        case '/messages/unread-counts':
          return jsonResponse({
            'counts_by_sender_id': {},
            'total_unread_count': 0,
          });
        default:
          throw StateError('${request.url}');
      }
    });
    final service = ChatRealtimeService(
      chatApi: api,
      baseUri: Uri.parse('https://api.test'),
      session: session,
      notificationService: NotificationService(),
    );
    final controller = ChatConversationHomeController();
    addTearDown(service.dispose);
    addTearDown(controller.dispose);
    final imageKey = GlobalKey();
    await tester.pumpWidget(
      LocalizedTestApp(
        theme: AppTheme.light,
        builder: (context, child) => RepaintBoundary(
          key: imageKey,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: 44, bottom: 34)),
            child: child!,
          ),
        ),
        home: ChatConversationHomeScreen(
          chatApi: api,
          realtimeService: service,
          session: session,
          controller: controller,
          messageCache: ChatMessageCache(
            chatApi: api,
            currentUserId: me.id,
            persistenceEnabled: false,
          ),
          onProfileUpdated: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No friends added yet.'), findsOneWidget);
    final headerButtons = tester.widgetList<AppRoundIconButton>(
      find.byType(AppRoundIconButton),
    );
    expect(headerButtons.length, 2);
    expect(
      headerButtons.every(
        (button) =>
            button.backgroundColor == Colors.transparent &&
            button.borderColor == Colors.transparent,
      ),
      isTrue,
    );
    await tester.tap(find.byIcon(AppIcons.personAdd));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Maya');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('@Maya'), findsOneWidget);
    await _capture(tester, imageKey, 'friend-result');
    await tester.tap(find.byIcon(AppIcons.add));
    await tester.pumpAndSettle();
    expect(find.text('Requested'), findsOneWidget);
    await _capture(tester, imageKey, 'friend-added');
    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    expect(find.text('No friends added yet.'), findsOneWidget);
    added = true;
    controller.refreshFriends();
    await tester.pumpAndSettle();
    expect(find.text('Maya 🌿'), findsOneWidget);
    expect(find.text('@Maya'), findsOneWidget);
    await _capture(tester, imageKey, 'friends');
    await tester.tap(find.byIcon(AppIcons.settings));
    await tester.pumpAndSettle();
    expect(find.text('June'), findsOneWidget);
    await _capture(tester, imageKey, 'settings');
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await _capture(tester, imageKey, 'language');
    await tester.tap(find.text('Español'));
    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    await _capture(tester, imageKey, 'change-photo');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

// 같은 테스트 화면을 시안과 대조할 때만 로컬 PNG로 내보내요.
Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_ACCOUNT_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/private/tmp/naru-$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
