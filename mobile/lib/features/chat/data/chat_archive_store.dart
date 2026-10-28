import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 보관은 이 기기의 목록에만 적용하고, 친구 관계와 메시지는 바꾸지 않아요.
final class ChatArchiveStore {
  const ChatArchiveStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  String _key(String userId) => 'naru.chat_archive.v1.$userId';

  Future<Set<String>> load(String userId) async {
    final value = await _storage.read(key: _key(userId));
    return value == null
        ? <String>{}
        : (jsonDecode(value) as List<dynamic>).cast<String>().toSet();
  }

  Future<void> save(String userId, Set<String> archivedUserIds) => _storage
      .write(key: _key(userId), value: jsonEncode(archivedUserIds.toList()));
}
