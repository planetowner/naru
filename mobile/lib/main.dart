import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'core/config/app_config.dart';
import 'core/l10n/app_strings.dart';
import 'core/notifications/notification_service.dart';
import 'design_system/app_theme.dart';
import 'design_system/components/app_launch_screen.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_exception.dart';
import 'features/auth/data/auth_refresh_exception.dart';
import 'features/auth/data/auth_session_store.dart';
import 'features/auth/domain/auth_session.dart';
import 'features/auth/domain/app_user.dart';
import 'features/auth/domain/app_language.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/chat/data/chat_api.dart';
import 'features/chat/data/chat_realtime_service.dart';
import 'features/chat/presentation/chat_conversation_screen.dart';

void main() {
  final AppConfig appConfig = AppConfig.fromEnvironment();

  runApp(NaruApp(appConfig: appConfig));
}

final class NaruApp extends StatefulWidget {
  const NaruApp({required this.appConfig, super.key});

  final AppConfig appConfig;

  @override
  State<NaruApp> createState() {
    return _NaruAppState();
  }
}

final class _NaruAppState extends State<NaruApp> with WidgetsBindingObserver {
  static const Duration _accessTokenRefreshLeadTime = Duration(days: 1);
  static const Duration _accessTokenRefreshRetryDelay = Duration(minutes: 5);

  late final http.Client _httpClient;
  late final AuthApi _authApi;
  late final AuthSessionStore _authSessionStore;
  late final NotificationService _notificationService;
  late final ChatConversationHomeController _chatController;
  StreamSubscription<Map<String, dynamic>>? _notificationEventSubscription;
  Timer? _accessTokenRefreshTimer;

  AuthSession? _session;
  AppLanguage? _onboardingLanguage;
  ChatApi? _chatApi;
  ChatRealtimeService? _chatRealtimeService;
  bool _isRestoringSession = true;
  bool _hasLoadedInitialChatList = false;
  bool _isRefreshingSession = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _httpClient = http.Client();
    _notificationService = NotificationService();
    _chatController = ChatConversationHomeController();
    _notificationEventSubscription = _notificationService.events.listen(
      _handleNotificationEvent,
    );

    _authApi = AuthApi(
      client: _httpClient,
      baseUri: widget.appConfig.apiBaseUri,
    );
    _authSessionStore = const AuthSessionStore();

    unawaited(_clearDeliveredNotifications());
    unawaited(_restoreSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_notificationEventSubscription?.cancel());
    _accessTokenRefreshTimer?.cancel();
    _chatRealtimeService?.dispose();
    _chatController.dispose();
    _httpClient.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_clearDeliveredNotifications());
      unawaited(_refreshActiveSessionIfNeeded());
    }
  }

  Future<void> _clearDeliveredNotifications() async {
    try {
      await _notificationService.clearDeliveredNotifications();
    } on PlatformException catch (error) {
      debugPrint('Delivered notification cleanup failed: ${error.message}');
    } on MissingPluginException {
      debugPrint('Notification bridge is unavailable on this platform.');
    }
  }

  void _handleNotificationEvent(Map<String, dynamic> event) {
    if (event['type'] == 'notification.received') {
      _chatController.refreshFriends();
      return;
    }
    if (event['type'] != 'notification.opened') {
      return;
    }

    final dynamic rawPayload = event['payload'];
    if (rawPayload is! Map) {
      return;
    }

    final Map<String, dynamic> payload = Map<String, dynamic>.from(rawPayload);
    _chatController.openNotification(payload);
  }

  Future<void> _restoreSession() async {
    AuthSession? session;

    try {
      session = await _authSessionStore.load();
    } on Exception catch (error) {
      debugPrint('Session restoration failed: $error');
    }

    if (session != null) {
      try {
        final AuthSession refreshedSession = await _authApi.refresh(
          refreshToken: session.refreshToken,
        );
        await _authSessionStore.save(refreshedSession);
        session = refreshedSession;
      } on AuthRefreshException catch (error) {
        if (error.statusCode == 401) {
          await _clearStoredSession();
          session = null;
        } else {
          debugPrint('Session refresh failed: $error');
        }
      } on Exception catch (error) {
        debugPrint('Session refresh failed: $error');
      }
    }

    if (!mounted) {
      return;
    }

    if (session != null) {
      _activateChatSession(session);
    } else {
      _deactivateChatSession();
    }

    setState(() {
      _session = session;
      _isRestoringSession = false;
    });

    if (session != null) {
      unawaited(_configureNotifications(session));
    }
  }

  Future<void> _authenticate({
    required String username,
    required String password,
    String? displayName,
    String? passwordConfirmation,
    String? preferredLanguage,
  }) async {
    final AuthSession session = passwordConfirmation == null
        ? await _authApi.login(username: username, password: password)
        : await _authApi.register(
            username: username,
            displayName: displayName!,
            password: password,
            passwordConfirmation: passwordConfirmation,
            preferredLanguage: preferredLanguage!,
          );

    // 가입과 로그인은 보안 저장·채팅 연결·알림 등록을 같은 순서로 처리해요.
    try {
      await _authSessionStore.save(session);
    } on Exception catch (error) {
      debugPrint('Session persistence failed: $error');
      throw const AuthException(
        'Could not save your session securely. Please sign in again.',
      );
    }

    if (!mounted) {
      return;
    }

    _activateChatSession(session);

    setState(() {
      _session = session;
    });

    unawaited(_configureNotifications(session));
  }

  Future<void> _updateProfile(AppUser user) async {
    final current = _session!;
    final session = current.withUser(user);
    await _authSessionStore.save(session);
    if (!mounted) return;
    _activateChatSession(session);
    setState(() => _session = session);
    unawaited(_configureNotifications(session));
  }

  Future<void> _configureNotifications(AuthSession session) async {
    try {
      await _notificationService.configure(
        apiBaseUri: widget.appConfig.apiBaseUri,
        session: session,
      );
    } on PlatformException catch (error) {
      debugPrint('Notification configuration failed: ${error.message}');
    } on MissingPluginException {
      debugPrint('Notification bridge is unavailable on this platform.');
    }
  }

  Future<void> _refreshActiveSessionIfNeeded() async {
    final AuthSession? session = _session;
    if (session == null || _isRefreshingSession) {
      return;
    }

    final DateTime? expiresAt = session.accessTokenExpiresAt;
    final DateTime refreshBoundary = DateTime.now().toUtc().add(
      _accessTokenRefreshLeadTime,
    );
    if (expiresAt != null && expiresAt.isAfter(refreshBoundary)) {
      return;
    }

    await _refreshActiveSession(session);
  }

  Future<void> _refreshActiveSession(AuthSession session) async {
    if (_isRefreshingSession || _session != session) {
      return;
    }

    _isRefreshingSession = true;

    try {
      final AuthSession refreshedSession = await _authApi.refresh(
        refreshToken: session.refreshToken,
      );

      try {
        await _authSessionStore.save(refreshedSession);
      } on Exception catch (error) {
        debugPrint('Refreshed session persistence failed: $error');
      }

      if (!mounted || _session != session) {
        return;
      }

      _activateChatSession(refreshedSession);
      setState(() {
        _session = refreshedSession;
      });
      unawaited(_configureNotifications(refreshedSession));
    } on AuthRefreshException catch (error) {
      if (error.statusCode == 401) {
        await _clearStoredSession();

        if (!mounted || _session != session) {
          return;
        }

        _deactivateChatSession();
        setState(() {
          _session = null;
        });
      } else {
        debugPrint('Session refresh failed: $error');
        _scheduleAccessTokenRefresh(
          session,
          retryAfter: _accessTokenRefreshRetryDelay,
        );
      }
    } on Exception catch (error) {
      debugPrint('Session refresh failed: $error');
      _scheduleAccessTokenRefresh(
        session,
        retryAfter: _accessTokenRefreshRetryDelay,
      );
    } finally {
      _isRefreshingSession = false;
    }
  }

  Future<void> _clearStoredSession() async {
    try {
      await _authSessionStore.clear();
    } on Exception catch (error) {
      debugPrint('Session cleanup failed: $error');
    }
  }

  void _activateChatSession(AuthSession session) {
    _chatRealtimeService?.dispose();

    final ChatApi chatApi = ChatApi(
      client: _httpClient,
      baseUri: widget.appConfig.apiBaseUri,
      accessToken: session.accessToken,
      preferredLanguage: session.user.preferredLanguage,
    );
    final ChatRealtimeService realtimeService = ChatRealtimeService(
      chatApi: chatApi,
      baseUri: widget.appConfig.apiBaseUri,
      session: session,
      notificationService: _notificationService,
    );

    _chatApi = chatApi;
    _chatRealtimeService = realtimeService;
    realtimeService.start();
    _scheduleAccessTokenRefresh(session);
  }

  void _deactivateChatSession() {
    _accessTokenRefreshTimer?.cancel();
    _accessTokenRefreshTimer = null;
    _chatRealtimeService?.dispose();
    _chatRealtimeService = null;
    _chatApi = null;
  }

  void _scheduleAccessTokenRefresh(
    AuthSession session, {
    Duration? retryAfter,
  }) {
    _accessTokenRefreshTimer?.cancel();

    final DateTime? expiresAt = session.accessTokenExpiresAt;
    final Duration refreshDelay;

    if (retryAfter != null) {
      refreshDelay = retryAfter;
    } else if (expiresAt == null) {
      refreshDelay = Duration.zero;
    } else {
      final DateTime refreshAt = expiresAt.subtract(
        _accessTokenRefreshLeadTime,
      );
      final Duration remaining = refreshAt.difference(DateTime.now().toUtc());
      refreshDelay = remaining.isNegative ? Duration.zero : remaining;
    }

    // 앱이 계속 켜져 있어도 만료 하루 전에 새 액세스 토큰을 받아요.
    _accessTokenRefreshTimer = Timer(refreshDelay, () {
      unawaited(_refreshActiveSession(session));
    });
  }

  Widget _buildHome() {
    if (_isRestoringSession) {
      return const SizedBox.expand();
    }

    final AuthSession? session = _session;

    if (session == null) {
      return AuthScreen(
        onSubmit: _authenticate,
        onLanguageChanged: (language) =>
            setState(() => _onboardingLanguage = language),
      );
    }

    final ChatApi? chatApi = _chatApi;
    final ChatRealtimeService? realtimeService = _chatRealtimeService;

    if (chatApi == null || realtimeService == null) {
      return const SizedBox.expand();
    }

    return ChatConversationHomeScreen(
      // 언어가 바뀌면 메모리 캐시도 새 언어의 API로 다시 읽어요.
      key: ValueKey((session.accessToken, session.user.preferredLanguage)),
      chatApi: chatApi,
      realtimeService: realtimeService,
      session: session,
      controller: _chatController,
      onInitialLoadComplete: _handleInitialChatListLoaded,
      onProfileUpdated: _updateProfile,
    );
  }

  void _handleInitialChatListLoaded() {
    if (_hasLoadedInitialChatList) {
      return;
    }

    setState(() {
      _hasLoadedInitialChatList = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'naru',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: _session != null
          ? AppLanguage.fromCode(_session!.user.preferredLanguage).locale
          : _onboardingLanguage?.locale,
      localeListResolutionCallback: AppLanguage.resolveLocales,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // 시작 화면과 앱 화면 모두 흰 배경에 맞는 상태 막대 색을 사용해요.
      builder: (BuildContext context, Widget? child) {
        return AppLaunchGate(
          isReady:
              !_isRestoringSession &&
              (_session == null || _hasLoadedInitialChatList),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.lightSystemUi,
            child: child!,
          ),
        );
      },
      home: _buildHome(),
    );
  }
}
