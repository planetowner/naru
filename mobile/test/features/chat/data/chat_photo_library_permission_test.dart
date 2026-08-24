import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juliatalk/features/chat/data/chat_photo_library.dart';
import 'package:photo_manager/photo_manager.dart';

const MethodChannel _photoManagerChannel = MethodChannel(
  'com.fluttercandies/photo_manager',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
