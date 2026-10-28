import '../../auth/domain/app_user.dart';

final class FriendSearchResult {
  const FriendSearchResult({
    required this.user,
    required this.isFriend,
    this.outgoingRequestId,
    this.incomingRequestId,
  });
  factory FriendSearchResult.fromJson(Map<String, dynamic> json) =>
      FriendSearchResult(
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
        isFriend: json['is_friend'] as bool,
        outgoingRequestId: json['outgoing_request_id'] as String?,
        incomingRequestId: json['incoming_request_id'] as String?,
      );
  final AppUser user;
  final bool isFriend;
  final String? outgoingRequestId;
  final String? incomingRequestId;
}
