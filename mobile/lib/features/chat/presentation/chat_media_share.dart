import 'package:flutter/services.dart';

final class ChatMediaShare {
  const ChatMediaShare._();

  static const MethodChannel _channel = MethodChannel('juliatalk/media-share');

  static Future<void> shareFile(String path) {
    return _channel.invokeMethod<void>('share-file', <String, Object>{
      'path': path,
    });
  }
}
