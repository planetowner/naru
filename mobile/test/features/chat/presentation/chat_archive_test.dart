import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/core/l10n/app_strings.dart';
import 'package:naru/core/notifications/notification_service.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/features/account/presentation/user_tile.dart';
import 'package:naru/features/auth/domain/app_user.dart';
import 'package:naru/features/auth/domain/auth_session.dart';
import 'package:naru/features/chat/data/chat_archive_store.dart';
import 'package:naru/features/chat/data/chat_message_cache.dart';
import 'package:naru/features/chat/data/chat_realtime_service.dart';
import 'package:naru/features/chat/presentation/chat_archive_tile.dart';
import 'package:naru/features/chat/presentation/chat_conversation_screen.dart';

import '../../../support/load_app_fonts.dart';
import '../../../support/localized_test_app.dart';
import '../../account/account_api_test.dart' show apiFor, jsonResponse;

const _friends = [
  AppUser(
    id: 'alice',
    username: 'alice',
    displayName: 'Alice',
    preferredLanguage: 'en',
  ),
  AppUser(
    id: 'bob',
    username: 'bob',
    displayName: 'Bob',
    preferredLanguage: 'ko',
  ),
];

Future<ChatConversationHomeController> _pumpHome(
  WidgetTester tester, {
  String username = 'planetowner',
  ChatArchiveStore store = const ChatArchiveStore(),
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final me = AppUser(
    id: 'me',
    username: username,
    displayName: 'planetowner',
    preferredLanguage: 'en',
  );
  final session = AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    tokenType: 'bearer',
    user: me,
  );
  final api = apiFor((request) async {
    // 보관과 복원은 서버의 친구 관계나 메시지를 수정하지 않아요.
    expect(request.method, 'GET');
    switch (request.url.path) {
      case '/users':
        return jsonResponse(_friends.map((user) => user.toJson()).toList());
      case '/users/friend-requests':
      case '/messages/conversation/alice':
      case '/messages/conversation/bob':
        return jsonResponse([]);
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
  await tester.pumpWidget(
    LocalizedTestApp(
      theme: AppTheme.light,
      home: ChatConversationHomeScreen(
        chatApi: api,
        realtimeService: service,
        session: session,
        controller: controller,
        archiveStore: store,
        messageCache: ChatMessageCache(
          chatApi: api,
          currentUserId: me.id,
          persistenceEnabled: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _archive(WidgetTester tester, String name) async {
  await tester.drag(find.text(name), const Offset(-180, 0));
  await tester.pumpAndSettle();
  expect(find.text(name), findsOneWidget);
  await tester.tap(find.text('Archive'));
  await tester.pumpAndSettle();
  expect(find.text(name), findsNothing);
}

Future<void> _pullToRestore(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'archive storage is scoped by account and leaves other saved data intact',
    () async {
      const store = ChatArchiveStore();
      const storage = FlutterSecureStorage();
      await storage.write(key: 'naru.auth_session.v1', value: 'session');
      await store.save('owner', {'alice', 'bob'});
      await store.save('another', {'carol'});
      expect(await const ChatArchiveStore().load('owner'), {'alice', 'bob'});
      await store.save('owner', {});
      expect(await store.load('owner'), isEmpty);
      expect(await store.load('another'), {'carol'});
      expect(await storage.read(key: 'naru.auth_session.v1'), 'session');
    },
  );

  testWidgets(
    'swiping only reveals Archive; tapping hides across reload and restart',
    (tester) async {
      final controller = await _pumpHome(tester, username: 'PlanetOwner');
      expect(find.byType(ChatArchiveTile), findsNWidgets(2));
      expect(find.text('Archive'), findsNothing);
      await _archive(tester, 'Alice');
      expect(find.text('Bob'), findsOneWidget);
      expect(await const ChatArchiveStore().load('me'), {'alice'});
      controller.refreshFriends();
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await _pumpHome(tester);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Bob'), findsOneWidget);
      await _pullToRestore(tester);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pulling an entirely archived list restores everyone permanently',
    (tester) async {
      await _pumpHome(tester);
      await _archive(tester, 'Alice');
      await _archive(tester, 'Bob');
      expect(find.byType(UserTile), findsNothing);
      expect(find.text('No friends added yet.'), findsNothing);
      await _pullToRestore(tester);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(await const ChatArchiveStore().load('me'), isEmpty);

      await tester.pumpWidget(const SizedBox());
      await _pumpHome(tester);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      await _archive(tester, 'Alice');
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'other usernames cannot archive, even with matching display name or stored ids',
    (tester) async {
      await const ChatArchiveStore().save('me', {'alice'});
      await _pumpHome(tester, username: 'other');
      expect(find.text('Alice'), findsOneWidget);
      expect(find.byType(ChatArchiveTile), findsNothing);
      expect(find.byType(RefreshIndicator), findsNothing);
      await tester.drag(find.text('Alice'), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Alice'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'right swipe closes Archive and vertical scrolling never archives',
    (tester) async {
      await _pumpHome(tester);
      await tester.drag(find.text('Alice'), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsOneWidget);
      await tester.drag(
        find.byType(ChatArchiveTile).first,
        const Offset(180, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsNothing);
      await tester.drag(find.text('Alice'), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsNothing);
      expect(await const ChatArchiveStore().load('me'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed persistence keeps the row visible and allows retry', (
    tester,
  ) async {
    final storage = _FailingStorage();
    await _pumpHome(tester, store: ChatArchiveStore(storage: storage));
    await tester.drag(find.text('Alice'), const Offset(-180, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(await const ChatArchiveStore().load('me'), isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
    storage.fail = false;
    await _archive(tester, 'Alice');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('archive action fits all eight languages and enlarged text', (
    tester,
  ) async {
    for (final language in ['ko', 'en', 'ja', 'zh', 'es', 'fr', 'de', 'it']) {
      await tester.pumpWidget(
        LocalizedTestApp(
          language: language,
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: ChatArchiveTile(
              key: ValueKey(language),
              onArchive: () {},
              child: UserTile(user: _friends.first),
            ),
          ),
        ),
      );
      await tester.drag(find.text('Alice'), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(
        find.text(stringsForLanguage(language).archiveChat),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}

class _FailingStorage extends FlutterSecureStorage {
  bool fail = true;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (fail) throw PlatformException(code: 'write_failed');
    return super.write(key: key, value: value);
  }
}
