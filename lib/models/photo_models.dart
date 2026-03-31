// 文件说明：数据模型层代码，负责 JSON 与业务对象转换。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 数据模型模块：定义前后端交互对象结构，负责 JSON 与业务对象互转。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

class PhotoTag {
  PhotoTag({required this.name, required this.type});
  final String name;
  final String type;

  factory PhotoTag.fromJson(Map<String, dynamic> j) => PhotoTag(
        name: j['tag_name']?.toString() ?? '',
        type: j['tag_type']?.toString() ?? '',
      );
}

/// `PhotoListItem`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class PhotoListItem {
  PhotoListItem({
    required this.id,
    required this.imageUrl,
    this.title,
    this.description,
    this.locationName,
    this.cameraModel,
    this.focalLength,
    this.aperture,
    this.shutterSpeed,
    this.iso,
    this.username,
    this.avatarUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.favoritesCount = 0,
    this.tags = const [],
    this.isLiked = false,
    this.isFavorited = false,
    this.latitude,
    this.longitude,
    this.userId,
  });

  final int id;
  final String imageUrl;
  final String? title;
  final String? description;
  final String? locationName;
  final String? cameraModel;
  final String? focalLength;
  final String? aperture;
  final String? shutterSpeed;
  final int? iso;
  final String? username;
  final String? avatarUrl;
  final int likesCount;
  final int commentsCount;
  final int favoritesCount;
  final List<PhotoTag> tags;
  final bool isLiked;
  final bool isFavorited;
  final double? latitude;
  final double? longitude;

  /// 作者用户 ID（动态流接口 `user_id`）。
  final int? userId;

  factory PhotoListItem.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    List<PhotoTag> tags = [];
    if (tagsRaw is List) {
      tags = tagsRaw
          .map((e) => PhotoTag.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return PhotoListItem(
      id: _jsonInt(json['id']),
      imageUrl: json['image_url']?.toString() ?? '',
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      locationName: json['location_name']?.toString(),
      cameraModel: json['camera_model']?.toString(),
      focalLength: json['focal_length']?.toString(),
      aperture: json['aperture']?.toString(),
      shutterSpeed: json['shutter_speed']?.toString(),
      iso: _jsonIntNullable(json['iso']),
      username: json['username']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      likesCount: _jsonIntNullable(json['likes_count']) ?? 0,
      commentsCount: _jsonIntNullable(json['comments_count']) ?? 0,
      favoritesCount: _jsonIntNullable(json['favorites_count']) ?? 0,
      tags: tags,
      isLiked: json['is_liked'] == true,
      isFavorited: json['is_favorited'] == true,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      userId: _jsonIntNullable(json['user_id']),
    );
  }

  /// 云函数/pg 序列化可能把 bigint 落成字符串，避免 `as num` 崩溃。
  static int _jsonInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static int? _jsonIntNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  PhotoListItem copyWith({
    int? id,
    String? imageUrl,
    String? title,
    String? description,
    String? locationName,
    String? cameraModel,
    String? focalLength,
    String? aperture,
    String? shutterSpeed,
    int? iso,
    String? username,
    String? avatarUrl,
    int? likesCount,
    int? commentsCount,
    int? favoritesCount,
    List<PhotoTag>? tags,
    bool? isLiked,
    bool? isFavorited,
    double? latitude,
    double? longitude,
    int? userId,
  }) {
    return PhotoListItem(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      locationName: locationName ?? this.locationName,
      cameraModel: cameraModel ?? this.cameraModel,
      focalLength: focalLength ?? this.focalLength,
      aperture: aperture ?? this.aperture,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      iso: iso ?? this.iso,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      tags: tags ?? this.tags,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      userId: userId ?? this.userId,
    );
  }
}

/// `PhotoComment`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class PhotoComment {
  PhotoComment({
    required this.id,
    required this.content,
    this.username,
    this.avatarUrl,
    this.createdAt,
  });

  final int id;
  final String content;
  final String? username;
  final String? avatarUrl;
  final String? createdAt;

  factory PhotoComment.fromJson(Map<String, dynamic> json) {
    return PhotoComment(
      id: (json['id'] as num).toInt(),
      content: json['content']?.toString() ?? '',
      username: json['username']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

/// `PhotoDetail`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class PhotoDetail extends PhotoListItem {
  PhotoDetail({
    required super.id,
    required super.imageUrl,
    super.title,
    super.description,
    super.locationName,
    super.cameraModel,
    super.focalLength,
    super.aperture,
    super.shutterSpeed,
    super.iso,
    super.username,
    super.avatarUrl,
    super.likesCount,
    super.commentsCount,
    super.favoritesCount,
    super.tags,
    super.isLiked,
    super.isFavorited,
    super.latitude,
    super.longitude,
    super.userId,
    this.cameraBrand,
    this.userBio,
    this.shootingTips,
    this.comments = const [],
  });

  final String? cameraBrand;
  final String? userBio;
  final String? shootingTips;
  final List<PhotoComment> comments;

  factory PhotoDetail.fromJson(Map<String, dynamic> json) {
    final base = PhotoListItem.fromJson(json);
    final commentsRaw = json['comments'];
    List<PhotoComment> comments = [];
    if (commentsRaw is List) {
      comments = commentsRaw
          .map((e) => PhotoComment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return PhotoDetail(
      id: base.id,
      imageUrl: base.imageUrl,
      title: base.title,
      description: base.description,
      locationName: base.locationName,
      cameraModel: base.cameraModel,
      focalLength: base.focalLength,
      aperture: base.aperture,
      shutterSpeed: base.shutterSpeed,
      iso: base.iso,
      username: base.username,
      avatarUrl: base.avatarUrl,
      likesCount: base.likesCount,
      commentsCount: base.commentsCount,
      favoritesCount: base.favoritesCount,
      tags: base.tags,
      isLiked: base.isLiked,
      isFavorited: base.isFavorited,
      latitude: base.latitude,
      longitude: base.longitude,
      userId: base.userId ?? (json['user_id'] as num?)?.toInt(),
      cameraBrand: json['camera_brand']?.toString(),
      userBio: json['user_bio']?.toString(),
      shootingTips: json['shooting_tips']?.toString(),
      comments: comments,
    );
  }

  @override
  PhotoDetail copyWith({
    int? id,
    String? imageUrl,
    String? title,
    String? description,
    String? locationName,
    String? cameraModel,
    String? focalLength,
    String? aperture,
    String? shutterSpeed,
    int? iso,
    String? username,
    String? avatarUrl,
    int? likesCount,
    int? commentsCount,
    int? favoritesCount,
    List<PhotoTag>? tags,
    bool? isLiked,
    bool? isFavorited,
    double? latitude,
    double? longitude,
    int? userId,
    String? cameraBrand,
    String? userBio,
    String? shootingTips,
    List<PhotoComment>? comments,
  }) {
    return PhotoDetail(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      locationName: locationName ?? this.locationName,
      cameraModel: cameraModel ?? this.cameraModel,
      focalLength: focalLength ?? this.focalLength,
      aperture: aperture ?? this.aperture,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      iso: iso ?? this.iso,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      tags: tags ?? this.tags,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      userId: userId ?? this.userId,
      cameraBrand: cameraBrand ?? this.cameraBrand,
      userBio: userBio ?? this.userBio,
      shootingTips: shootingTips ?? this.shootingTips,
      comments: comments ?? this.comments,
    );
  }
}

/// `Pagination`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class Pagination {
  Pagination({required this.page, required this.limit, required this.total});
  final int page;
  final int limit;
  final int total;
}
