import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:naru/core/l10n/app_strings.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/design_system/components/components.dart';
import 'package:naru/features/account/presentation/profile_photo_picker_screen.dart';
import 'package:naru/features/chat/data/chat_photo_library.dart';
import 'package:naru/features/chat/presentation/chat_photo_picker.dart';
import 'package:naru/features/account/presentation/settings_screen.dart';
import 'package:naru/features/auth/domain/app_language.dart';

import '../../support/load_app_fonts.dart';
import '../../support/naru_preview_app.dart' show TestChatPhotoLibrary;
import '../../support/localized_test_app.dart';
import '../../support/pump_real_async_until.dart';
import 'account_api_test.dart' show apiFor, jsonResponse, user;

final _croppedBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/w'
  'HwAEAQH/2p3KAAAAAElFTkSuQmCC',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  final cropChannels = <MethodChannel>[];
  late Future<Object?> Function(MethodCall) cropHandler;
  late List<int> pickedSources;
  late List<Uint8List> nativePhotos;
  late Directory photoDirectory;
  bool cancelCamera = false;

  setUp(() {
    pickedSources = [];
    nativePhotos = [];
    cancelCamera = false;
    photoDirectory = Directory.systemTemp.createTempSync(
      'naru-profile-picker-',
    );
    File('${photoDirectory.path}/camera.png').writeAsBytesSync(_croppedBytes);
    cropHandler = (call) async => call.method == 'crop' ? _croppedBytes : null;
    messenger.setMockMethodCallHandler(pickerChannel, (call) async {
      pickedSources.add((call.arguments as Map)['source'] as int);
      return cancelCamera ? null : '${photoDirectory.path}/camera.png';
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        expect(args['viewType'], 'naru/photo-crop');
        final params =
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(args['params'] as Uint8List),
                )
                as Map;
        expect(params['bytes'], isA<Uint8List>());
        nativePhotos.add(params['bytes'] as Uint8List);
        final channel = MethodChannel('naru/photo-crop/${args['id']}');
        cropChannels.add(channel);
        messenger.setMockMethodCallHandler(
          channel,
          (call) => cropHandler(call),
        );
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pickerChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in cropChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    cropChannels.clear();
    photoDirectory.deleteSync(recursive: true);
  });

  Future<void> choosePhoto(WidgetTester tester, String source) async {
    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    if (source == 'Camera') {
      final previousCount = nativePhotos.length;
      await tester.tap(find.byKey(const ValueKey('photo-picker-camera')));
      await pumpRealAsyncUntil(
        tester,
        () => nativePhotos.length > previousCount,
        failureReason: 'A camera photo should load in the same crop viewport.',
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> openPicker(
    WidgetTester tester, {
    ChatPhotoLibrary photoLibrary = const TestChatPhotoLibrary(),
    String language = 'en',
    ValueChanged<XFile?>? onResult,
  }) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        key: ValueKey(language),
        theme: AppTheme.light,
        language: language,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<XFile>(
                MaterialPageRoute(
                  builder: (_) =>
                      ProfilePhotoPickerScreen(photoLibrary: photoLibrary),
                ),
              );
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final source in [
    ('Photo', ImageSource.gallery),
    ('Camera', ImageSource.camera),
  ]) {
    testWidgets(
      '${source.$1} uses crop, cancel preserves preview, Save uploads only cropped bytes',
      (tester) async {
        final calls = <String>[];
        final saved = Completer<void>();
        final api = apiFor((request) async {
          calls.add('${request.method} ${request.url.path}');
          switch (request.url.path) {
            case '/media-assets':
              final body = jsonDecode(request.body) as Map;
              expect(body['file_name'], 'profile-photo.jpg');
              expect(body['mime_type'], 'image/jpeg');
              return jsonResponse({
                'media_asset_id': 'cropped',
                'upload_url': 'https://storage.test/cropped.jpg',
                'upload_headers': {'Content-Type': 'image/jpeg'},
              }, 201);
            case '/cropped.jpg':
              expect(request.bodyBytes, _croppedBytes);
              return http.Response('', 200);
            case '/media-assets/cropped/complete':
              return jsonResponse({});
            case '/users/me':
              expect(jsonDecode(request.body)['photo_asset_id'], 'cropped');
              return jsonResponse(user.toJson());
            default:
              throw StateError('${request.url}');
          }
        });
        await tester.pumpWidget(
          LocalizedTestApp(
            theme: AppTheme.light,
            home: SettingsScreen(
              user: user,
              photoLibrary: const TestChatPhotoLibrary(),
              chatApi: api,
              onSaved: (_) async => saved.complete(),
            ),
          ),
        );
        await choosePhoto(tester, source.$1);
        expect(
          pickedSources,
          source.$2 == ImageSource.camera
              ? [ImageSource.camera.index]
              : isEmpty,
        );
        expect(find.text('Profile photo'), findsOneWidget);
        await tester.tap(find.byTooltip('Done'));
        await tester.pumpAndSettle();
        final preview = tester.widget<AppProfileImage>(
          find.byType(AppProfileImage),
        );
        expect((preview.image! as MemoryImage).bytes, _croppedBytes);
        expect(calls, isEmpty);
        await choosePhoto(tester, source.$1);
        await tester.tap(find.byTooltip('Cancel'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AppProfileImage>(find.byType(AppProfileImage)).image,
          preview.image,
        );
        expect(calls, isEmpty);
        // 기존 업로드는 StreamedRequest를 쓰므로 실제 비동기 큐에서 끝까지 기다려요.
        await tester.tap(find.text('Save'));
        await pumpRealAsyncUntil(
          tester,
          () => saved.isCompleted,
          failureReason:
              'The cropped photo should upload before the profile is saved.',
        );
        await tester.pumpAndSettle();
        expect(calls, [
          'POST /media-assets',
          'PUT /cropped.jpg',
          'POST /media-assets/cropped/complete',
          'PATCH /users/me',
        ]);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'native load failure prevents completion and cancel leaves photo unchanged',
    (tester) async {
      cropHandler = (_) async =>
          throw PlatformException(code: 'photo_unavailable');
      await tester.pumpWidget(
        LocalizedTestApp(
          theme: AppTheme.light,
          home: SettingsScreen(
            user: user,
            photoLibrary: const TestChatPhotoLibrary(),
            chatApi: apiFor((_) async => throw StateError('Should not upload')),
            onSaved: (_) async {},
          ),
        ),
      );
      await choosePhoto(tester, 'Photo');
      expect(find.text('Photos could not be loaded.'), findsOneWidget);
      final done = tester.widget<AppRoundIconButton>(
        find.byKey(const ValueKey('profile-photo-done')),
      );
      expect(done.onPressed, isNull);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppProfileImage>(find.byType(AppProfileImage)).image,
        isNull,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'crop failure can retry and pending crop cannot be dismissed',
    (tester) async {
      final pending = Completer<Object?>();
      int renders = 0;
      cropHandler = (call) async {
        if (call.method != 'crop') return null;
        if (++renders == 1) throw PlatformException(code: 'crop_failed');
        return pending.future;
      };
      XFile? result;
      await openPicker(tester, onResult: (photo) => result = photo);
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Photos could not be loaded.'), findsOneWidget);
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      expect(
        tester.widget<AppNavigationBar>(find.byType(AppNavigationBar)).onBack,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Profile photo'), findsOneWidget);
      pending.complete(_croppedBytes);
      await tester.pumpAndSettle();
      expect(result!.mimeType, 'image/jpeg');
      expect(result!.name, 'profile-photo.jpg');
      expect(await result!.readAsBytes(), _croppedBytes);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'crop labels reuse all eight app languages',
    (tester) async {
      for (final language in AppLanguage.values) {
        final strings = stringsForLanguage(language.code);
        await openPicker(tester, language: language.code);
        expect(find.text(strings.profilePhoto), findsOneWidget);
        expect(find.byTooltip(strings.done), findsOneWidget);
        await tester.tap(find.byTooltip(strings.cancel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'one shared picker selects immediately, keeps crop across albums, and ignores stale loads',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final library = _ControlledPhotoLibrary();
      await openPicker(tester, photoLibrary: library);
      expect(find.byType(ChatPhotoPicker), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-picker-send')), findsNothing);
      expect(find.byKey(const ValueKey('photo-picker-handle')), findsNothing);
      expect(
        find.byKey(const ValueKey('photo-selection-badge-asset-0')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('profile-photo-crop'))),
        const Size(390, 390),
      );
      expect(tester.getSize(find.byType(UiKitView)), const Size(390, 390));
      expect(tester.getTopLeft(find.byType(UiKitView)).dx, 0);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('profile-photo-crop'))).dy,
        100,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('photo-asset-grid'))).dy,
        542,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('photo-asset-grid'))).height,
        268,
      );
      expect(nativePhotos, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('photo-album-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(nativePhotos, hasLength(1));
      final slow = Completer<ChatPhotoFile?>();
      library.originals['favorite-0'] = slow.future;
      await tester.tap(find.byKey(const ValueKey('photo-tile-favorite-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('photo-tile-favorite-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('photo-selection-badge-favorite-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('photo-selection-badge-favorite-0')),
        findsNothing,
      );
      final created = nativePhotos.length;
      slow.complete(
        await const TestChatPhotoLibrary().loadOriginalFile(
          assetId: 'favorite-0',
        ),
      );
      await tester.pumpAndSettle();
      expect(nativePhotos, hasLength(created));
      cancelCamera = true;
      await tester.tap(find.byKey(const ValueKey('photo-picker-camera')));
      await tester.pumpAndSettle();
      expect(nativePhotos, hasLength(created));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a delayed album load must not replace a photo just taken with the camera',
    (tester) async {
      final albums = Completer<List<ChatPhotoAlbum>>();
      final library = _ControlledPhotoLibrary()..albums = albums.future;
      await openPicker(tester, photoLibrary: library);
      await tester.tap(find.byTooltip('Camera'));
      await pumpRealAsyncUntil(
        tester,
        () => nativePhotos.isNotEmpty,
        failureReason:
            'The camera photo should open before album loading finishes.',
      );
      await tester.pumpAndSettle();
      final created = nativePhotos.length;
      albums.complete(await const TestChatPhotoLibrary().loadAlbums());
      await tester.pumpAndSettle();
      expect(nativePhotos, hasLength(created));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'small and landscape layouts keep crop and picker visible, including denied access',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [const Size(320, 568), const Size(844, 390)]) {
        for (final access in [
          ChatPhotoAccessState.authorized,
          ChatPhotoAccessState.denied,
        ]) {
          await tester.binding.setSurfaceSize(size);
          await openPicker(
            tester,
            photoLibrary: _ControlledPhotoLibrary(access: access),
          );
          expect(tester.takeException(), isNull);
          final crop = tester.getRect(
            find.byKey(const ValueKey('profile-photo-crop')),
          );
          expect(crop.width, crop.height);
          expect(crop.right, lessThanOrEqualTo(size.width));
          expect(crop.bottom, lessThanOrEqualTo(size.height));
          if (access == ChatPhotoAccessState.denied) {
            expect(find.byType(UiKitView), findsNothing);
            expect(
              tester
                  .widget<AppRoundIconButton>(
                    find.byKey(const ValueKey('profile-photo-done')),
                  )
                  .onPressed,
              isNull,
            );
            expect(find.byTooltip('Camera'), findsOneWidget);
          }
          await tester.tap(find.byTooltip('Cancel'));
          await tester.pumpAndSettle();
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

final class _ControlledPhotoLibrary implements ChatPhotoLibrary {
  _ControlledPhotoLibrary({this.access = ChatPhotoAccessState.authorized});
  final ChatPhotoAccessState access;
  final originals = <String, Future<ChatPhotoFile?>>{};
  Future<List<ChatPhotoAlbum>>? albums;
  final _base = const TestChatPhotoLibrary();
  @override
  Future<ChatPhotoAccessState> requestAccess() async => access;
  @override
  Future<List<ChatPhotoAlbum>> loadAlbums() => albums ?? _base.loadAlbums();
  @override
  Future<List<ChatPhotoAsset>> loadAssets({
    required String albumId,
    required int page,
    required int pageSize,
  }) => _base.loadAssets(albumId: albumId, page: page, pageSize: pageSize);
  @override
  Future<Uint8List?> loadThumbnail({
    required String assetId,
    required int width,
    required int height,
  }) => _base.loadThumbnail(assetId: assetId, width: width, height: height);
  @override
  Future<Uint8List?> loadMessagePreview({required String assetId}) =>
      _base.loadMessagePreview(assetId: assetId);
  @override
  Future<ChatPhotoFile?> loadOriginalFile({required String assetId}) =>
      originals[assetId] ?? _base.loadOriginalFile(assetId: assetId);
  @override
  Future<void> openSettings() => _base.openSettings();
}
