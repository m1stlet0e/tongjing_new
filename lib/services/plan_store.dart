import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PlanItem {
  PlanItem({
    required this.photoId,
    required this.title,
    required this.location,
    required this.imageUrl,
    required this.cameraLine,
    this.tips,
    this.done = false,
    required this.createdAt,
  });

  final int photoId;
  final String title;
  final String location;
  final String imageUrl;
  final String cameraLine;
  final String? tips;
  final bool done;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'photo_id': photoId,
        'title': title,
        'location': location,
        'image_url': imageUrl,
        'camera_line': cameraLine,
        'tips': tips,
        'done': done,
        'created_at': createdAt,
      };

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
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

class PlanStore {
  static const _key = 'tongjing_plan_items_v1';

  Future<List<PlanItem>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final arr = jsonDecode(raw);
    if (arr is! List) return [];
    return arr
        .map((e) => PlanItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 当前作品是否已在拍摄计划中。
  Future<bool> containsPhoto(int photoId) async {
    final items = await list();
    return items.any((e) => e.photoId == photoId);
  }

  Future<void> upsert(PlanItem item) async {
    final items = await list();
    final next = items.where((e) => e.photoId != item.photoId).toList();
    next.insert(0, item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> setDone(int photoId, bool done) async {
    final items = await list();
    final next = items
        .map(
          (e) => e.photoId == photoId
              ? PlanItem(
                  photoId: e.photoId,
                  title: e.title,
                  location: e.location,
                  imageUrl: e.imageUrl,
                  cameraLine: e.cameraLine,
                  tips: e.tips,
                  done: done,
                  createdAt: e.createdAt,
                )
              : e,
        )
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }
}
