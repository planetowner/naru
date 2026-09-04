import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juliatalk/features/chat/data/chat_photo_library.dart';
import 'package:photo_manager/photo_manager.dart';

const MethodChannel _photoManagerChannel = MethodChannel(
  'com.fluttercandies/photo_manager',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object?> assetData(String id) {
    return <String, Object?>{
      'id': id,
      'type': AssetType.image.index,
      'width': 1200,
      'height': 900,
      'duration': 0,
      'createDt': 1,
      'modifiedDt': 1,
    };
  }

  test('requests access after checking an undetermined permission', () async {
    final List<String> methodCalls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_photoManagerChannel, (
          MethodCall call,
        ) async {
          methodCalls.add(call.method);

          return switch (call.method) {
            'getPermissionState' => PermissionState.notDetermined.index,
            'requestPermissionExtend' => PermissionState.authorized.index,
            _ => throw MissingPluginException(call.method),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_photoManagerChannel, null);
    });

    final PhotoManagerChatPhotoLibrary photoLibrary =
        PhotoManagerChatPhotoLibrary();

    expect(await photoLibrary.checkAccess(), ChatPhotoAccessState.denied);
    expect(await photoLibrary.requestAccess(), ChatPhotoAccessState.authorized);
    expect(methodCalls, <String>[
      'getPermissionState',
      'requestPermissionExtend',
    ]);
  });

  test('cached album queries still include assets saved later', () async {
    final List<MethodCall> assetListCalls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_photoManagerChannel, (
          MethodCall call,
        ) async {
          return switch (call.method) {
            'getAssetPathList' => <String, Object?>{
              'data': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'all',
                  'name': 'Recents',
                  'assetCount': 1,
                  'isAll': true,
                  'albumType': 1,
                },
              ],
            },
            'getAssetCountFromPath' => 1,
            'getAssetListPaged' => () {
              assetListCalls.add(call);
              return <String, Object?>{
                'data': <Map<String, Object?>>[assetData('asset-1')],
              };
            }(),
            _ => throw MissingPluginException(call.method),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_photoManagerChannel, null);
    });

    final PhotoManagerChatPhotoLibrary photoLibrary =
        PhotoManagerChatPhotoLibrary();

    final List<ChatPhotoAlbum> albums = await photoLibrary.loadAlbums();
    photoLibrary.invalidateAssetListingCache();
    await photoLibrary.loadAssets(
      albumId: albums.single.id,
      page: 0,
      pageSize: 60,
    );

    expect(assetListCalls, hasLength(2));

    for (final MethodCall call in assetListCalls) {
      final Map<Object?, Object?> arguments =
          call.arguments as Map<Object?, Object?>;
      final Map<Object?, Object?> option =
          arguments['option'] as Map<Object?, Object?>;
      final Map<Object?, Object?> child =
          option['child'] as Map<Object?, Object?>;
      final Map<Object?, Object?> createDate =
          child['createDate'] as Map<Object?, Object?>;

      // 캐시된 앨범 객체를 재사용해도 최초 조회 시각이 상한이 되면 안 돼요.
      expect(createDate['ignore'], isTrue);
    }
  });
}
