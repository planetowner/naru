import '../../auth/domain/app_user.dart';

final class FriendSearchResult {
  const FriendSearchResult({required this.user, required this.isFriend});
  factory FriendSearchResult.fromJson(Map<String, dynamic> json) =>
      FriendSearchResult(
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
        isFriend: json['is_friend'] as bool,
      );
  final AppUser user;
  final bool isFriend;
}
