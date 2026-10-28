import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naru/features/chat/data/chat_photo_library.dart';
import 'package:naru/features/chat/data/chat_video_transcoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('naru/video-transcoder');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the encoded file metadata from the iOS bridge', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          expect(call.method, 'transcode');
          expect(call.arguments, <String, Object>{
            'input_path': '/tmp/source.mov',
          });
          return <String, Object>{
            'local_path': '/tmp/encoded.mp4',
            'file_name': 'encoded.mp4',
            'mime_type': 'video/mp4',
            'size_bytes': 3891466,
            'width': 1080,
            'height': 1920,
            'duration_ms': 9398,
          };
        });

    final ChatVideoTranscodeResult result =
        await const MethodChannelChatVideoTranscoder().transcode(
          source: ChatPhotoFile(
            bytes: Uint8List(0),
            fileName: 'source.mov',
            mimeType: 'video/quicktime',
            sizeBytes: 10767102,
            localPath: '/tmp/source.mov',
          ),
          width: 1080,
          height: 1920,
          duration: const Duration(milliseconds: 9398),
        );

    expect(result.localPath, '/tmp/encoded.mp4');
    expect(result.fileName, 'encoded.mp4');
    expect(result.mimeType, 'video/mp4');
    expect(result.sizeBytes, 3891466);
    expect(result.width, 1080);
    expect(result.height, 1920);
    expect(result.duration, const Duration(milliseconds: 9398));
    expect(result.uploadBytes, isNull);
  });

  test('passes the selected trim range to the iOS bridge', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          expect(call.method, 'transcode');
          expect(call.arguments, <String, Object>{
            'input_path': '/tmp/source.mov',
            'trim_start_ms': 1250,
            'trim_end_ms': 6750,
          });
          return <String, Object>{
            'local_path': '/tmp/encoded.mp4',
            'file_name': 'encoded.mp4',
            'mime_type': 'video/mp4',
            'size_bytes': 2200000,
            'width': 1080,
            'height': 1920,
            'duration_ms': 5500,
          };
        });

    final ChatVideoTranscodeResult result =
        await const MethodChannelChatVideoTranscoder().transcode(
          source: ChatPhotoFile(
            bytes: Uint8List(0),
            fileName: 'source.mov',
            mimeType: 'video/quicktime',
            sizeBytes: 10767102,
            localPath: '/tmp/source.mov',
          ),
          width: 1080,
          height: 1920,
          duration: const Duration(seconds: 10),
          trimRange: const ChatVideoTrimRange(
            start: Duration(milliseconds: 1250),
            end: Duration(milliseconds: 6750),
          ),
        );

    expect(result.duration, const Duration(milliseconds: 5500));
  });
}
