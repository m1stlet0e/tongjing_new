// 文件说明：服务层代码，负责 API 通信、响应解析与错误归一化处理。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 服务层模块：封装与后端 API 的通信、请求头处理、响应解析与异常归一化。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/models/challenge_models.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/models/plan_item.dart';
import 'package:tongjing/models/user_model.dart';

typedef TokenGetter = String? Function();

/// `ApiException`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// `ApiService`：业务服务，负责封装接口调用与领域逻辑复用。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class ApiService {
  ApiService(this._tokenGetter);

  final TokenGetter _tokenGetter;

  Uri _u(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_jsonHeaders`。
  Map<String, String> _jsonHeaders({bool auth = true}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    final t = auth ? _tokenGetter() : null;
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_authOnlyHeaders`。
  Map<String, String> _authOnlyHeaders() {
    final t = _tokenGetter();
    if (t == null || t.isEmpty) {
      throw ApiException('请先登录');
    }
    return {'Authorization': 'Bearer $t'};
  }

  Future<Map<String, dynamic>> _decodeJson(http.Response r) async {
    try {
      final body = r.body.isEmpty ? '{}' : r.body;
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('响应解析失败', r.statusCode);
    }
  }

  static String networkUnreachableMessage() =>
      '无法连接服务器（${AppConfig.apiBaseUrl}）。请在本机启动 Spring 服务（端口 9091）；真机请使用：flutter run --dart-define=API_BASE_URL=http://<电脑局域网IP>:9091';

  static bool _isNetworkFailure(Object e) {
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('Connection refused') ||
        s.contains('ClientException') ||
        s.contains('Network is unreachable') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection reset');
  }

  Future<T> _guardNetwork<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (e is ApiException) rethrow;
      if (_isNetworkFailure(e)) {
        throw ApiException(networkUnreachableMessage());
      }
      rethrow;
    }
  }

  // --- Auth ---
  Future<void> authSendCode(String phone, {String type = 'login'}) async {
    try {
      final res = await http.post(
        _u('/api/v1/auth/send-code'),
        headers: _jsonHeaders(auth: false),
        body: jsonEncode({'phone': phone, 'type': type}),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '发送验证码失败', res.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      if (_isNetworkFailure(e)) {
        throw ApiException(networkUnreachableMessage());
      }
      rethrow;
    }
  }

  /// 开发环境服务端可能在 JSON 中返回 `_dev_code`
  Future<({UserModel user, String token})> authLoginPhone(
      String phone, String code) async {
    try {
      final res = await http.post(
        _u('/api/v1/auth/login/phone'),
        headers: _jsonHeaders(auth: false),
        body: jsonEncode({'phone': phone, 'code': code}),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '登录失败', res.statusCode);
      }
      final data = j['data'] as Map<String, dynamic>;
      final user =
          UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
      final token = data['token'] as String;
      return (user: user, token: token);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (_isNetworkFailure(e)) {
        throw ApiException(networkUnreachableMessage());
      }
      rethrow;
    }
  }

  Future<void> authLogout() async {
    final res = await http.post(
      _u('/api/v1/auth/logout'),
      headers: _authOnlyHeaders(),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '退出失败', res.statusCode);
    }
  }

  Future<UserModel> authMe() async {
    final res = await http.get(
      _u('/api/v1/auth/me'),
      headers: _authOnlyHeaders(),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '获取用户失败', res.statusCode);
    }
    return UserModel.fromJson(Map<String, dynamic>.from(j['data'] as Map));
  }

  // --- Photos ---
  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_tabApiValue`。
  String _tabApiValue(String uiTab) {
    switch (uiTab) {
      case 'recommend':
        return 'recommend';
      case 'latest':
        return 'latest';
      case 'following':
        return 'following';
      default:
        return 'recommend';
    }
  }

  Future<({List<PhotoListItem> photos, Pagination pagination})> photosFeed({
    int page = 1,
    int limit = 20,
    String uiTab = 'recommend',
    String? camera,
    String? lens,
    String? scene,
  }) async {
    return _guardNetwork(() async {
      final q = <String, String>{
        'page': '$page',
        'limit': '$limit',
        'tab': _tabApiValue(uiTab),
      };
      if (camera != null && camera.isNotEmpty) q['camera'] = camera;
      if (lens != null && lens.isNotEmpty) q['lens'] = lens;
      if (scene != null && scene.isNotEmpty) q['scene'] = scene;

      final res = await http.get(
        _u('/api/v1/photos', q),
        headers: _jsonHeaders(auth: _tokenGetter() != null),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载失败', res.statusCode);
      }
      final data = j['data'] as Map<String, dynamic>;
      final list = (data['photos'] as List<dynamic>? ?? [])
          .map((e) => PhotoListItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final p = data['pagination'] as Map<String, dynamic>? ?? {};
      final pagination = Pagination(
        page: (p['page'] as num?)?.toInt() ?? page,
        limit: (p['limit'] as num?)?.toInt() ?? limit,
        total: (p['total'] as num?)?.toInt() ?? 0,
      );
      return (photos: list, pagination: pagination);
    });
  }

  Future<({List<PhotoListItem> photos, Pagination pagination})> photosMy({
    int page = 1,
    int limit = 20,
  }) async {
    return _guardNetwork(() async {
      final res = await http.get(
        _u('/api/v1/photos/my', {'page': '$page', 'limit': '$limit'}),
        headers: _authOnlyHeaders(),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载失败', res.statusCode);
      }
      final data = j['data'] as Map<String, dynamic>;
      final list = (data['photos'] as List<dynamic>? ?? [])
          .map((e) => PhotoListItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final p = data['pagination'] as Map<String, dynamic>? ?? {};
      final pagination = Pagination(
        page: (p['page'] as num?)?.toInt() ?? page,
        limit: (p['limit'] as num?)?.toInt() ?? limit,
        total: (p['total'] as num?)?.toInt() ?? 0,
      );
      return (photos: list, pagination: pagination);
    });
  }

  Future<({List<PhotoListItem> photos, Pagination pagination})>
      photosFavorites({
    int page = 1,
    int limit = 20,
  }) async {
    return _guardNetwork(() async {
      final res = await http.get(
        _u('/api/v1/photos/favorites', {'page': '$page', 'limit': '$limit'}),
        headers: _authOnlyHeaders(),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载失败', res.statusCode);
      }
      final data = j['data'] as Map<String, dynamic>;
      final list = (data['photos'] as List<dynamic>? ?? [])
          .map((e) => PhotoListItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final p = data['pagination'] as Map<String, dynamic>? ?? {};
      final pagination = Pagination(
        page: (p['page'] as num?)?.toInt() ?? page,
        limit: (p['limit'] as num?)?.toInt() ?? limit,
        total: (p['total'] as num?)?.toInt() ?? 0,
      );
      return (photos: list, pagination: pagination);
    });
  }

  Future<PhotoDetail> photoDetail(int id) async {
    return _guardNetwork(() async {
      final res = await http.get(
        _u('/api/v1/photos/$id'),
        headers: _jsonHeaders(auth: _tokenGetter() != null),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载失败', res.statusCode);
      }
      return PhotoDetail.fromJson(Map<String, dynamic>.from(j['data'] as Map));
    });
  }

  Future<void> photoPublish({
    required String imageUrl,
    required String title,
    String? description,
    String? shootingTips,
    String? locationName,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? exifData,
    List<Map<String, String>>? tags,
  }) async {
    final body = <String, dynamic>{
      'image_url': imageUrl,
      'title': title,
      if (description != null) 'description': description,
      if (shootingTips != null) 'shooting_tips': shootingTips,
      if (locationName != null) 'location_name': locationName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (exifData != null) 'exif_data': exifData,
      if (tags != null) 'tags': tags,
    };
    final res = await http.post(
      _u('/api/v1/photos'),
      headers: _jsonHeaders(),
      body: jsonEncode(body),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '发布失败', res.statusCode);
    }
  }

  Future<bool> photoToggleLike(int id) async {
    final res = await http.post(
      _u('/api/v1/photos/$id/like'),
      headers: _authOnlyHeaders(),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '操作失败', res.statusCode);
    }
    final data = j['data'] as Map<String, dynamic>? ?? {};
    return data['is_liked'] == true;
  }

  Future<bool> photoToggleFavorite(int id) async {
    final res = await http.post(
      _u('/api/v1/photos/$id/favorite'),
      headers: _authOnlyHeaders(),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '操作失败', res.statusCode);
    }
    final data = j['data'] as Map<String, dynamic>? ?? {};
    return data['is_favorited'] == true;
  }

  Future<void> photoAddComment(int id, String content) async {
    final res = await http.post(
      _u('/api/v1/photos/$id/comments'),
      headers: _jsonHeaders(),
      body: jsonEncode({'content': content}),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '评论失败', res.statusCode);
    }
  }

  Future<void> photoDelete(int id) async {
    final res = await http.delete(
      _u('/api/v1/photos/$id'),
      headers: _authOnlyHeaders(),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '删除失败', res.statusCode);
    }
  }

  // --- Upload ---
  Future<Map<String, dynamic>> uploadImage(String filePath) async {
    final uri = _u('/api/v1/upload/image');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authOnlyHeaders());
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '上传失败', res.statusCode);
    }
    return Map<String, dynamic>.from(j['data'] as Map);
  }

  // --- Users ---
  Future<UserModel> usersMe() async {
    final res = await http.get(
      _u('/api/v1/users/me'),
      headers: _authOnlyHeaders(),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '获取资料失败', res.statusCode);
    }
    return UserModel.fromJson(Map<String, dynamic>.from(j['data'] as Map));
  }

  Future<UserModel> usersPatchMe({
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    final res = await http.patch(
      _u('/api/v1/users/me'),
      headers: _jsonHeaders(),
      body: jsonEncode(body),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '更新失败', res.statusCode);
    }
    return UserModel.fromJson(Map<String, dynamic>.from(j['data'] as Map));
  }

  /// 公开用户资料（含 `is_following`，未登录时为 false）。
  Future<UserModel> usersPublic(int userId) async {
    return _guardNetwork(() async {
      final res = await http.get(
        _u('/api/v1/users/$userId'),
        headers: _jsonHeaders(auth: _tokenGetter() != null),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '用户不存在', res.statusCode);
      }
      return UserModel.fromJson(Map<String, dynamic>.from(j['data'] as Map));
    });
  }

  Future<({List<PhotoListItem> photos, Pagination pagination})> usersPublicPhotos(
    int userId, {
    int page = 1,
    int limit = 24,
  }) async {
    return _guardNetwork(() async {
      final res = await http.get(
        _u('/api/v1/users/$userId/photos', {'page': '$page', 'limit': '$limit'}),
        headers: _jsonHeaders(auth: _tokenGetter() != null),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载作品失败', res.statusCode);
      }
      final data = j['data'] as Map<String, dynamic>;
      final list = (data['photos'] as List<dynamic>? ?? [])
          .map((e) => PhotoListItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final p = data['pagination'] as Map<String, dynamic>? ?? {};
      final pagination = Pagination(
        page: (p['page'] as num?)?.toInt() ?? page,
        limit: (p['limit'] as num?)?.toInt() ?? limit,
        total: (p['total'] as num?)?.toInt() ?? 0,
      );
      return (photos: list, pagination: pagination);
    });
  }

  /// 切换关注，返回当前是否已关注。
  Future<bool> usersFollowToggle(int userId) async {
    return _guardNetwork(() async {
      final res = await http.post(
        _u('/api/v1/users/$userId/follow'),
        headers: _jsonHeaders(),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '操作失败', res.statusCode);
      }
      final data = j['data'] as Map<String, dynamic>? ?? {};
      return data['is_following'] == true;
    });
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final uri = _u('/api/v1/upload/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authOnlyHeaders());
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '上传失败', res.statusCode);
    }
    return Map<String, dynamic>.from(j['data'] as Map);
  }

  // --- Map ---
  Future<List<PhotoListItem>> mapPhotos({
    required double lat,
    required double lng,
    String radiusKm = '50',
  }) async {
    return _guardNetwork(() async {
      final res = await http.get(
        _u('/api/v1/map/photos', {
          'lat': '$lat',
          'lng': '$lng',
          'radius': radiusKm,
        }),
        headers: _jsonHeaders(auth: _tokenGetter() != null),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '地图数据失败', res.statusCode);
      }
      final raw = j['data'];
      if (raw is! List) return <PhotoListItem>[];
      return raw
          .map((e) => PhotoListItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
  }

  Future<List<Map<String, dynamic>>> mapPopularSpots() async {
    return _guardNetwork(() async {
      final res = await http.get(_u('/api/v1/map/popular-spots'));
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '热门机位失败', res.statusCode);
      }
      final raw = j['data'];
      if (raw is! List) return <Map<String, dynamic>>[];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  // --- Spots ---
  Future<List<Map<String, dynamic>>> spotsMy() async {
    final res = await http.get(
      _u('/api/v1/spots/my'),
      headers: _authOnlyHeaders(),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '机位列表失败', res.statusCode);
    }
    final data = j['data'] as Map<String, dynamic>? ?? {};
    final list = data['spots'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> spotsCreate({
    required String name,
    required String locationName,
    List<String>? tags,
    String bestTime = '全天',
    bool isPublic = true,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'location_name': locationName,
      'tags': tags ?? [],
      'best_time': bestTime,
      'is_public': isPublic,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    final res = await http.post(
      _u('/api/v1/spots'),
      headers: _jsonHeaders(),
      body: jsonEncode(body),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '保存失败', res.statusCode);
    }
  }

  Future<void> spotsUnlink(int spotId) async {
    final res = await http.delete(
      _u('/api/v1/spots/$spotId'),
      headers: _authOnlyHeaders(),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '删除失败', res.statusCode);
    }
  }

  // --- Equipment ---
  Future<List<Map<String, dynamic>>> equipmentForUser(int userId) async {
    final res = await http.get(_u('/api/v1/equipment/user/$userId'));
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '器材加载失败', res.statusCode);
    }
    final data = j['data'] as Map<String, dynamic>? ?? {};
    final list = data['equipment'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> equipmentRemoveFromUser(int userId, int equipmentId) async {
    final res = await http.delete(
      _u('/api/v1/equipment/user/$userId/$equipmentId'),
      headers: _authOnlyHeaders(),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '移除失败', res.statusCode);
    }
  }

  Future<List<Map<String, dynamic>>> equipmentCatalog() async {
    final res = await http.get(_u('/api/v1/equipment'));
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '目录加载失败', res.statusCode);
    }
    final data = j['data'] as Map<String, dynamic>? ?? {};
    final list = data['equipment'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> equipmentAddToUser(int userId, int equipmentId) async {
    final res = await http.post(
      _u('/api/v1/equipment/user/$userId'),
      headers: _jsonHeaders(),
      body: jsonEncode({'equipment_id': equipmentId}),
    );
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '添加失败', res.statusCode);
    }
  }

  // --- 拍摄计划（shoot_plans） ---
  Future<List<PlanItem>> shootPlansList() async {
    return _guardNetwork(() async {
      final res = await http.get(
        _u('/api/v1/shoot-plans'),
        headers: _authOnlyHeaders(),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '计划列表失败', res.statusCode);
      }
      final data = j['data'] as Map<String, dynamic>? ?? {};
      final list = data['plans'] as List<dynamic>? ?? <dynamic>[];
      return list
          .map((e) => PlanItem.fromServerJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
  }

  Future<PlanItem> shootPlanUpsert({
    required int photoId,
    required String title,
    required String location,
    required String imageUrl,
    required String cameraLine,
    String? tips,
    bool? done,
  }) async {
    return _guardNetwork(() async {
      final body = <String, dynamic>{
        'photo_id': photoId,
        'title': title,
        'location': location,
        'image_url': imageUrl,
        'camera_line': cameraLine,
        if (tips != null) 'tips': tips,
        if (done != null) 'done': done,
      };
      final res = await http.put(
        _u('/api/v1/shoot-plans'),
        headers: _jsonHeaders(),
        body: jsonEncode(body),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '保存计划失败', res.statusCode);
      }
      return PlanItem.fromServerJson(Map<String, dynamic>.from(j['data'] as Map));
    });
  }

  Future<void> shootPlanPatchDone(int planId, bool done) async {
    return _guardNetwork(() async {
      final res = await http.patch(
        _u('/api/v1/shoot-plans/$planId'),
        headers: _jsonHeaders(),
        body: jsonEncode({'done': done}),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '更新计划失败', res.statusCode);
      }
    });
  }

  Future<void> shootPlanDelete(int planId) async {
    return _guardNetwork(() async {
      final res = await http.delete(
        _u('/api/v1/shoot-plans/$planId'),
        headers: _jsonHeaders(),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '删除计划失败', res.statusCode);
      }
    });
  }

  // --- 挑战 ---
  Future<List<ChallengeItem>> challengesList() async {
    return _guardNetwork(() async {
      final res = await http.get(
        _u('/api/v1/challenges'),
        headers: _jsonHeaders(auth: _tokenGetter() != null),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '挑战列表失败', res.statusCode);
      }
      final data = j['data'] as Map<String, dynamic>? ?? {};
      final raw = data['challenges'] as List<dynamic>? ?? <dynamic>[];
      return raw
          .map((e) => ChallengeItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
  }

  Future<ChallengeItem> challengeDetail(int challengeId) async {
    return _guardNetwork(() async {
      final res = await http.get(
        _u('/api/v1/challenges/$challengeId'),
        headers: _jsonHeaders(auth: _tokenGetter() != null),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '挑战详情失败', res.statusCode);
      }
      return ChallengeItem.fromJson(Map<String, dynamic>.from(j['data'] as Map));
    });
  }

  Future<void> challengeJoin(int challengeId, {int? photoId}) async {
    return _guardNetwork(() async {
      final body = <String, dynamic>{if (photoId != null) 'photo_id': photoId};
      final res = await http.post(
        _u('/api/v1/challenges/$challengeId/join'),
        headers: _jsonHeaders(),
        body: jsonEncode(body),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '参与挑战失败', res.statusCode);
      }
    });
  }

  Future<({String copy, List<Map<String, String>> tags})> aiPublishAssist({
    required String title,
    String? description,
    String? locationName,
    Map<String, dynamic>? exifData,
  }) async {
    return _guardNetwork(() async {
      final body = <String, dynamic>{
        'title': title,
        if (description != null) 'description': description,
        if (locationName != null) 'location_name': locationName,
        if (exifData != null) 'exif_data': exifData,
      };
      final res = await http.post(
        _u('/api/v1/ai/publish-assist'),
        headers: _jsonHeaders(),
        body: jsonEncode(body),
      );
      final j = await _decodeJson(res);
      if (res.statusCode >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? 'AI 生成失败', res.statusCode);
      }
      final data = j['data'] as Map<String, dynamic>? ?? {};
      final copy = data['copy']?.toString() ?? '';
      final tagsRaw = data['tags'] as List<dynamic>? ?? <dynamic>[];
      final tags = tagsRaw
          .map((e) => Map<String, String>.from(Map<String, dynamic>.from(e as Map)))
          .toList();
      return (copy: copy, tags: tags);
    });
  }
}
