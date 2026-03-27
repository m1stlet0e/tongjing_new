/// 拍摄计划项（与后端 `shoot_plans` 对齐）。
class PlanItem {
  PlanItem({
    this.planId,
    required this.photoId,
    required this.title,
    required this.location,
    required this.imageUrl,
    required this.cameraLine,
    this.tips,
    this.done = false,
    required this.createdAt,
  });

  /// 服务端 `shoot_plans.id`，本地新建时尚未落库则为 null。
  final int? planId;
  final int photoId;
  final String title;
  final String location;
  final String imageUrl;
  final String cameraLine;
  final String? tips;
  final bool done;
  final String createdAt;

  factory PlanItem.fromServerJson(Map<String, dynamic> json) => PlanItem(
        planId: (json['id'] as num?)?.toInt(),
        photoId: (json['photo_id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '未命名计划',
        location: json['location']?.toString() ?? '未标记机位',
        imageUrl: json['image_url']?.toString() ?? '',
        cameraLine: json['camera_line']?.toString() ?? '参数待补充',
        tips: json['tips']?.toString(),
        done: json['done'] == true,
        createdAt: json['created_at']?.toString() ?? '',
      );
}
