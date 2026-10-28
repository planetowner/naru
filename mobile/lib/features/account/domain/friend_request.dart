import '../../auth/domain/app_user.dart';

final class FriendRequest {
  const FriendRequest({required this.id, required this.sender});

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id'] as String,
    sender: AppUser.fromJson(json['sender'] as Map<String, dynamic>),
  );

  final String id;
  final AppUser sender;
}

enum FriendRequestDecision { accept, decline }
