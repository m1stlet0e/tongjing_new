import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 发布页草稿（含已上传图片 URL 与 EXIF，可一键恢复编辑）。
class PublishDraftStore {
  static const _key = 'tongjing_publish_draft_v1';

  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String imageUrl,
    Map<String, dynamic>? exifData,
    required String title,
    required String caption,
    required String tips,
    required String location,
    required String lat,
    required String lng,
    required String tagType,
    required List<Map<String, String>> tags,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'image_url': imageUrl,
        'exif_data': exifData,
        'title': title,
        'caption': caption,
        'tips': tips,
        'location': location,
        'lat': lat,
        'lng': lng,
        'tag_type': tagType,
        'tags': tags,
        'saved_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<bool> hasDraft() async {
    final m = await load();
    if (m == null) return false;
    final url = m['image_url']?.toString();
    return url != null && url.isNotEmpty;
  }
}
