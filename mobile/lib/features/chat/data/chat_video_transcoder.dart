import 'package:flutter/services.dart';

import 'chat_photo_library.dart';

final class ChatVideoTrimRange {
  const ChatVideoTrimRange({required this.start, required this.end});

  final Duration start;
  final Duration end;

  Duration get duration => end - start;
}

final class ChatVideoTranscodeResult {
  const ChatVideoTranscodeResult({
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.duration,
    this.localPath,
    this.uploadBytes,
    this.previewBytes,
  });

  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final int width;
  final int height;
  final Duration duration;
  final String? localPath;
  final Uint8List? uploadBytes;
  final Uint8List? previewBytes;
}

abstract interface class ChatVideoTranscoder {
  Future<ChatVideoTranscodeResult> transcode({
    required ChatPhotoFile source,
    required int width,
    required int height,
    required Duration duration,
    ChatVideoTrimRange? trimRange,
  });
}

final class OriginalChatVideoTranscoder implements ChatVideoTranscoder {
  const OriginalChatVideoTranscoder();

  @override
  Future<ChatVideoTranscodeResult> transcode({
    required ChatPhotoFile source,
    required int width,
    required int height,
    required Duration duration,
    ChatVideoTrimRange? trimRange,
  }) async {
    return ChatVideoTranscodeResult(
      fileName: source.fileName,
      mimeType: source.mimeType,
      sizeBytes: source.sizeBytes,
      width: width,
      height: height,
      duration: trimRange?.duration ?? duration,
      localPath: source.localPath,
      uploadBytes: source.bytes,
    );
  }
}

final class MethodChannelChatVideoTranscoder implements ChatVideoTranscoder {
  const MethodChannelChatVideoTranscoder();

  static const MethodChannel _channel = MethodChannel(
    'naru/video-transcoder',
  );

  @override
  Future<ChatVideoTranscodeResult> transcode({
    required ChatPhotoFile source,
    required int width,
    required int height,
    required Duration duration,
    ChatVideoTrimRange? trimRange,
  }) async {
    final String? inputPath = source.localPath;

    if (inputPath == null || inputPath.isEmpty) {
      throw PlatformException(
        code: 'missing_input_path',
        message: 'The selected video has no local file path.',
      );
    }

    final Map<String, Object> arguments = <String, Object>{
      'input_path': inputPath,
    };
    if (trimRange case final ChatVideoTrimRange range) {
      arguments.addAll(<String, Object>{
        'trim_start_ms': range.start.inMilliseconds,
        'trim_end_ms': range.end.inMilliseconds,
      });
    }

    final Map<Object?, Object?>? value = await _channel
        .invokeMapMethod<Object?, Object?>('transcode', arguments);

    if (value == null) {
      throw PlatformException(
        code: 'invalid_transcode_result',
        message: 'The video encoder returned no result.',
      );
    }

    return ChatVideoTranscodeResult(
      fileName: _requiredString(value, 'file_name'),
      mimeType: _requiredString(value, 'mime_type'),
      sizeBytes: _requiredInt(value, 'size_bytes'),
      width: _requiredInt(value, 'width'),
      height: _requiredInt(value, 'height'),
      duration: Duration(milliseconds: _requiredInt(value, 'duration_ms')),
      localPath: _requiredString(value, 'local_path'),
      previewBytes: value['preview_bytes'] as Uint8List?,
    );
  }

  static String _requiredString(Map<Object?, Object?> value, String key) {
    final Object? field = value[key];

    if (field is String && field.isNotEmpty) {
      return field;
    }

    throw PlatformException(
      code: 'invalid_transcode_result',
      message: 'The video encoder returned an invalid $key.',
    );
  }

  static int _requiredInt(Map<Object?, Object?> value, String key) {
    final Object? field = value[key];

    if (field is int && field >= 0) {
      return field;
    }

    throw PlatformException(
      code: 'invalid_transcode_result',
      message: 'The video encoder returned an invalid $key.',
    );
  }
}
