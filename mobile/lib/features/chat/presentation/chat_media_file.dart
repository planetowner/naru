import 'package:flutter/services.dart';

final class ChatMediaFile {
  const ChatMediaFile._();

  static const MethodChannel _channel = MethodChannel('juliatalk/media-file');

  static Future<void> previewFile(String path) {
    return _channel.invokeMethod<void>('preview-file', <String, Object>{
      'path': path,
    });
  }

  static Future<void> shareFile(String path) {
    return _channel.invokeMethod<void>('share-file', <String, Object>{
      'path': path,
    });
  }
}
