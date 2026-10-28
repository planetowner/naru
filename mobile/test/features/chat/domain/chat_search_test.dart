import 'package:flutter_test/flutter_test.dart';
import 'package:naru/features/chat/domain/chat_link.dart';
import 'package:naru/features/chat/domain/chat_message.dart';
import 'package:naru/features/chat/domain/chat_search.dart';

ChatMessage message(
  String id, {
  String text = '',
  List<ChatPhotoAttachment> photos = const [],
  ChatVideoAttachment? video,
  ChatFileAttachment? file,
  ChatLinkPreview? link,
  int day = 16,
}) => ChatMessage(
  id: id,
  senderId: '1',
  recipientId: '2',
  content: text,
  createdAt: DateTime(2026, 10, day),
  photoAttachments: photos,
  videoAttachment: video,
  fileAttachment: file,
  linkPreview: link,
);

void main() {
  test('media expands every photo and filters by filename and type', () {
    final data = [
      message(
        'photos',
        photos: const [
          ChatPhotoAttachment(
            assetId: 'a',
            width: 10,
            height: 10,
            fileName: 'Trip.JPG',
          ),
          ChatPhotoAttachment(
            assetId: 'b',
            width: 10,
            height: 10,
            fileName: 'food.png',
          ),
        ],
      ),
      message(
        'video',
        video: const ChatVideoAttachment(
          assetId: 'v',
          width: 10,
          height: 10,
          duration: Duration(seconds: 12),
          fileName: 'Trip.MOV',
        ),
      ),
    ];
    final all = chatSearchEntries(data, category: ChatSearchCategory.media);
    expect(all.length, 3);
    expect(all.map((entry) => entry.id).toSet().length, 3);
    expect(
      chatSearchEntries(
        data,
        category: ChatSearchCategory.media,
        query: ' TRIP ',
      ).length,
      2,
    );
    expect(
      chatSearchEntries(
        data,
        category: ChatSearchCategory.media,
        query: 'trip',
        mediaFilter: ChatSearchMediaFilter.photos,
      ).single.photoIndex,
      0,
    );
    expect(
      chatSearchEntries(
        data,
        category: ChatSearchCategory.media,
        mediaFilter: ChatSearchMediaFilter.videos,
      ).single.video,
      isNotNull,
    );
  });
  test('links include all URLs once and use the existing preview title', () {
    final data = [
      message(
        'links',
        text: 'https://example.com/a, www.other.test/b! https://example.com/a',
        link: const ChatLinkPreview(
          url: 'https://example.com/a',
          domain: 'example.com',
          title: 'Weekend plans',
        ),
      ),
    ];
    final links = chatSearchEntries(data, category: ChatSearchCategory.links);
    expect(links.length, 2);
    expect(
      chatSearchEntries(
        data,
        category: ChatSearchCategory.links,
        query: 'WEEKEND',
      ).single.link!.title,
      'Weekend plans',
    );
    expect(
      chatSearchEntries(
        data,
        category: ChatSearchCategory.links,
        query: 'other.test',
      ).single.link!.url,
      'https://www.other.test/b',
    );
    expect(firstChatUrlInText(data.single.content), 'https://example.com/a');
  });
  test('files use attachment metadata, local date and newest order', () {
    final data = [
      message(
        'old',
        day: 14,
        file: const ChatFileAttachment(name: 'notes.pdf', sizeBytes: 100),
      ),
      message(
        'new',
        file: const ChatFileAttachment(name: 'notes.png', sizeBytes: 200),
      ),
      message(
        'photo',
        photos: const [
          ChatPhotoAttachment(
            assetId: 'x',
            width: 10,
            height: 10,
            fileName: 'notes.jpg',
          ),
        ],
      ),
    ];
    expect(
      chatSearchEntries(
        data,
        category: ChatSearchCategory.files,
      ).map((e) => e.message.id),
      ['new', 'old'],
    );
    expect(
      chatSearchEntries(
        data,
        category: ChatSearchCategory.files,
        date: DateTime(2026, 10, 14),
      ).single.file!.name,
      'notes.pdf',
    );
    expect(
      chatSearchEntries(
        data,
        category: ChatSearchCategory.files,
        query: 'missing',
      ),
      isEmpty,
    );
  });
  test('message matching retains translation and quoted reply search', () {
    final data = message('text', text: 'Hello').copyWith(
      translatedContent: '안녕',
      replyTo: const ChatReplyReference(
        messageId: 'original',
        senderId: '2',
        content: 'Weekend',
      ),
    );
    for (final query in ['hello', '안녕', 'weekend']) {
      expect(chatMessageMatchesQuery(data, query), isTrue);
    }
    expect(chatMessageMatchesQuery(data, ' '), isFalse);
    expect(
      chatMessageMatchesQuery(
        message(
          'file',
          text: 'Weekend',
          file: const ChatFileAttachment(name: 'Weekend.pdf', sizeBytes: 1),
        ),
        'Weekend',
      ),
      isFalse,
    );
  });
}
