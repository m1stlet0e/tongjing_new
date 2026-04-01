// 文件说明：数据模型层代码，负责 JSON 与业务对象转换。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 数据模型模块：定义前后端交互对象结构，负责 JSON 与业务对象互转。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

class UserModel {
  UserModel({
    required this.id,
    required this.username,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.photosCount,
    this.followersCount,
    this.followingCount,
    this.likesReceived,
    this.favoritesReceived,
    this.myFavoritesCount,
    this.myLikesCount,
    this.isFollowing,
  });

  final int id;
  final String username;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final int? photosCount;
  final int? followersCount;
  final int? followingCount;

  /// 他人对「我的作品」点赞次数累计（各作品 likes_count 之和）。
  final int? likesReceived;

  /// 他人收藏「我的作品」次数累计。
  final int? favoritesReceived;

  /// 我收藏的作品数量。
  final int? myFavoritesCount;

  /// 我点过赞的作品数量。
  final int? myLikesCount;

  /// 公开主页接口 [is_following]；`/me` 无此字段时为 null。
  final bool? isFollowing;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawFollow = json['is_following'];
    return UserModel(
      id: (json['id'] as num).toInt(),
      username: json['username']?.toString() ?? '',
      phone: json['phone']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      bio: json['bio']?.toString(),
      photosCount: (json['photos_count'] as num?)?.toInt(),
      followersCount: (json['followers_count'] as num?)?.toInt(),
      followingCount: (json['following_count'] as num?)?.toInt(),
      likesReceived: (json['likes_received'] as num?)?.toInt(),
      favoritesReceived: (json['favorites_received'] as num?)?.toInt(),
      myFavoritesCount: (json['my_favorites_count'] as num?)?.toInt(),
      myLikesCount: (json['my_likes_count'] as num?)?.toInt(),
      isFollowing: rawFollow == true
          ? true
          : rawFollow == false
              ? false
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (bio != null) 'bio': bio,
        if (photosCount != null) 'photos_count': photosCount,
        if (followersCount != null) 'followers_count': followersCount,
        if (followingCount != null) 'following_count': followingCount,
        if (likesReceived != null) 'likes_received': likesReceived,
        if (favoritesReceived != null) 'favorites_received': favoritesReceived,
        if (myFavoritesCount != null) 'my_favorites_count': myFavoritesCount,
        if (myLikesCount != null) 'my_likes_count': myLikesCount,
      };
}
