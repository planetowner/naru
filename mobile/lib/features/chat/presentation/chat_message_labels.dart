import '../../../core/l10n/app_strings.dart';
import '../domain/chat_message.dart';

String callOutcomeLabel(ChatCallOutcome outcome, AppLocalizations strings) =>
    switch (outcome) {
      ChatCallOutcome.started => strings.voiceCall,
      ChatCallOutcome.ended => strings.endVoiceCall,
      ChatCallOutcome.cancelled => strings.canceled,
      ChatCallOutcome.missed => strings.missedCall,
      ChatCallOutcome.noAnswer => strings.noAnswer,
    };

// 사진 같은 안내 문구만 번역하고, 사용자가 보낸 본문·파일명은 그대로 보여줘요.
String replyPreviewLabel(ChatReplyReference reply, AppLocalizations strings) =>
    switch (reply.messageType) {
      'voice_memo' => strings.voiceMemo,
      'video' => strings.video,
      'photo' =>
        reply.photoCount > 1
            ? strings.photoCount(reply.photoCount)
            : strings.photo,
      'file' => reply.content.isEmpty ? strings.file : reply.content,
      'call' => callOutcomeLabel(
        reply.callOutcome ?? ChatCallOutcome.started,
        strings,
      ),
      _ => reply.content,
    };

extension ChatMessageLabels on ChatMessage {
  ChatReplyReference replyReference({String? displayedContent}) =>
      ChatReplyReference(
        messageId: id,
        senderId: senderId,
        content:
            displayedContent ??
            (isFileMessage
                ? fileAttachment!.name
                : isLinkMessage
                ? linkPreview!.title ?? linkPreview!.domain
                : content),
        messageType: messageType,
        photoCount: photoAttachments.length,
        callOutcome: callAttachment?.outcome,
      );

  String localizedPreview(AppLocalizations strings) =>
      replyPreviewLabel(replyReference(), strings);
}
