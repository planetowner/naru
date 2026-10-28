import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/features/auth/domain/auth_session.dart';
import 'package:naru/features/auth/domain/app_user.dart';
import 'package:naru/core/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('naru/notifications');

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'notification actions use account language for all eight languages',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'requestAuthorization' ? true : null;
          });
      final labels = {
        'ko': ['답장', '전송'],
        'zh-CN': ['回复', '发送'],
        'ja': ['返信', '送信'],
        'en': ['Reply', 'Send'],
        'es': ['Responder', 'Enviar'],
        'fr': ['Répondre', 'Envoyer'],
        'de': ['Antworten', 'Senden'],
        'it': ['Rispondi', 'Invia'],
      };
      for (final entry in labels.entries) {
        calls.clear();
        await NotificationService().configure(
          apiBaseUri: Uri.parse('https://example.com'),
          session: AuthSession(
            accessToken: 'token',
            refreshToken: 'refresh',
            tokenType: 'bearer',
            user: AppUser(
              id: '1',
              username: 'test',
              displayName: 'Test',
              preferredLanguage: entry.key,
            ),
          ),
        );
        final args = calls.first.arguments as Map;
        expect(args['preferredLanguage'], entry.key);
        expect(args['replyActionTitle'], entry.value[0]);
        expect(args['sendActionTitle'], entry.value[1]);
        expect(calls.map((c) => c.method), [
          'configure',
          'requestAuthorization',
          'startVoIP',
        ]);
      }
    },
  );

  test(
    'clears delivered iOS notifications without changing the badge',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final List<MethodCall> methodCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            methodCalls.add(call);
            return null;
          });

      await NotificationService().clearDeliveredNotifications();

      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'clearDeliveredNotifications');
      expect(methodCalls.single.arguments, isNull);
    },
  );
}
