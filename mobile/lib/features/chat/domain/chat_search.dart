import 'chat_link.dart';
import 'chat_message.dart';

enum ChatSearchCategory {
  messages('Messages', 'Search messages'),
  media('Media', 'Search filenames'),
  links('Links', 'Search titles or URLs'),
  files('Files', 'Search filenames');

  const ChatSearchCategory(this.label, this.hint);
  final String label;
  final String hint;
}

enum ChatSearchMediaFilter { all, photos, videos }

DateTime chatSearchDate(DateTime value) {
  final DateTime local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

List<String> chatSearchableText(ChatMessage message) {
  if (message.isPhotoMessage ||
      message.isVideoMessage ||
      message.isFileMessage ||
      message.isCallMessage) {
    return const [];
  }
  return [
    message.content,
    if (message.translatedContent != null) message.translatedContent!,
    if (message.replyTo != null) message.replyTo!.content,
  ].where((text) => text.trim().isNotEmpty).toList();
}

bool chatMessageMatchesQuery(ChatMessage message, String query) {
  final String normalized = query.trim().toLowerCase();
  return normalized.isNotEmpty &&
      chatSearchableText(
        message,
      ).any((text) => text.toLowerCase().contains(normalized));
}

/// 한 메시지의 여러 사진과 링크도 각각 찾을 수 있게 펼쳐요.
final class ChatSearchEntry {
  const ChatSearchEntry({required this.message, this.photoIndex, this.link});
  final ChatMessage message;
  final int? photoIndex;
  final ChatLinkPreview? link;

  ChatPhotoAttachment? get photo =>
      photoIndex == null ? null : message.photoAttachments[photoIndex!];
  ChatVideoAttachment? get video =>
      photoIndex == null && link == null ? message.videoAttachment : null;
  ChatFileAttachment? get file => message.fileAttachment;
  String get id => '${message.id}:${photoIndex ?? link?.url ?? 'attachment'}';
  String get title =>
      link?.title ??
      link?.domain ??
      photo?.fileName ??
      video?.fileName ??
      file?.name ??
      (video == null ? 'Photo' : 'Video');

  bool matches(String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      title,
      if (link != null) ...[link!.url, link!.domain],
    ].any((text) => text.toLowerCase().contains(normalized));
  }
}

List<ChatSearchEntry> chatSearchEntries(
  Iterable<ChatMessage> messages, {
  required ChatSearchCategory category,
  String query = '',
  ChatSearchMediaFilter mediaFilter = ChatSearchMediaFilter.all,
  DateTime? date,
}) {
  final List<ChatMessage> sorted = messages.toList()
    ..sort((a, b) => compareChatMessages(b, a));
  final List<ChatSearchEntry> entries = [];
  for (final ChatMessage message in sorted) {
    if (date != null &&
        chatSearchDate(message.createdAt) != chatSearchDate(date)) {
      continue;
    }
    switch (category) {
      case ChatSearchCategory.messages:
        break;
      case ChatSearchCategory.media:
        if (mediaFilter != ChatSearchMediaFilter.videos) {
          for (int i = 0; i < message.photoAttachments.length; i++) {
            entries.add(ChatSearchEntry(message: message, photoIndex: i));
          }
        }
        if (mediaFilter != ChatSearchMediaFilter.photos &&
            message.videoAttachment != null) {
          entries.add(ChatSearchEntry(message: message));
        }
      case ChatSearchCategory.links:
        final ChatLinkPreview? preview = message.linkPreview;
        final Set<String> urls = {
          if (preview != null) preview.url,
          ...chatUrlsInText(message.content),
        };
        for (final String url in urls) {
          entries.add(
            ChatSearchEntry(
              message: message,
              link: preview?.url == url
                  ? preview
                  : ChatLinkPreview(url: url, domain: chatDomainForUrl(url)),
            ),
          );
        }
      case ChatSearchCategory.files:
        // 사진·영상으로 보낸 자료와 파일로 보낸 첨부를 구분해요.
        if (message.fileAttachment != null) {
          entries.add(ChatSearchEntry(message: message));
        }
    }
  }
  return entries.where((entry) => entry.matches(query)).toList();
}
