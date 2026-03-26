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
  });

  final int id;
  final String username;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final int? photosCount;
  final int? followersCount;
  final int? followingCount;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num).toInt(),
      username: json['username']?.toString() ?? '',
      phone: json['phone']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      bio: json['bio']?.toString(),
      photosCount: (json['photos_count'] as num?)?.toInt(),
      followersCount: (json['followers_count'] as num?)?.toInt(),
      followingCount: (json['following_count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (bio != null) 'bio': bio,
      };
}
