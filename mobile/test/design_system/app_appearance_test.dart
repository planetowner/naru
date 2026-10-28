import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/design_system/app_theme.dart';
import 'package:naru/design_system/components/app_launch_screen.dart';
import 'package:naru/features/chat/data/chat_photo_library.dart';
import 'package:naru/features/chat/presentation/chat_photo_editor_screen.dart';
import 'package:naru/features/chat/presentation/chat_photo_picker.dart';

import '../support/naru_preview_app.dart';
import '../support/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('launch screen matches the approved white ferry design', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AppLaunchScreen(),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/brand/naru-symbol.png'),
        tester.element(find.byType(AppLaunchScreen)),
      ),
    );
    await capture(tester, 'launch');
  });

  testWidgets('representative screens preserve layout and colors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const NaruPreviewApp());
    await capture(tester, 'chat-latest');
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('message-list')),
        matching: find.byType(Scrollable),
      ),
    );
    scrollable.position.jumpTo(scrollable.position.minScrollExtent);
    await capture(tester, 'chat-history');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ChatPhotoPicker(
            photoLibrary: _PhotoLibraryWithoutThumbnails(),
            onClose: () {},
            onSend: (_) async {},
            expanded: true,
          ),
        ),
      ),
    );
    await capture(tester, 'photo-picker');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Stack(
            children: [
              ChatPhotoEditorTopBar(
                visible: true,
                height: 126,
                topPadding: 59,
                currentIndex: 0,
                photoCount: 3,
                sending: false,
                onBackPressed: () {},
                onSendPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await capture(tester, 'photo-editor-top-bar');
  });
}

// 사진 파일 대신 빈 썸네일을 써서 선택기 배치와 색상을 일정하게 비교해요.
final class _PhotoLibraryWithoutThumbnails implements ChatPhotoLibrary {
  final _library = const TestChatPhotoLibrary();
  @override
  Future<ChatPhotoAccessState> requestAccess() => _library.requestAccess();
  @override
  Future<List<ChatPhotoAlbum>> loadAlbums() => _library.loadAlbums();
  @override
  Future<List<ChatPhotoAsset>> loadAssets({
    required String albumId,
    required int page,
    required int pageSize,
  }) => _library.loadAssets(albumId: albumId, page: page, pageSize: pageSize);
  @override
  Future<Uint8List?> loadThumbnail({
    required String assetId,
    required int width,
    required int height,
  }) async => null;
  @override
  Future<Uint8List?> loadMessagePreview({required String assetId}) async =>
      null;
  @override
  Future<ChatPhotoFile?> loadOriginalFile({required String assetId}) async =>
      null;
  @override
  Future<void> openSettings() async {}
}
