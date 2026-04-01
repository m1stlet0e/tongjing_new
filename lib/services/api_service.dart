// 文件说明：服务层代码，负责 API 通信、响应解析与错误归一化处理。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 服务层模块：封装与后端 API 的通信、请求头处理、响应解析与异常归一化。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/models/challenge_models.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/models/plan_item.dart';
import 'package:tongjing/models/user_model.dart';
import 'package:tongjing/services/api_exception.dart';
import 'package:tongjing/services/cloudbase_api_proxy.dart';
import 'package:tongjing/services/cloudbase_gate.dart';

export 'api_exception.dart';

typedef TokenGetter = String? Function();

/// `ApiService`：业务服务，负责封装接口调用与领域逻辑复用。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class ApiService {
  ApiService(this._tokenGetter) : _client = http.Client();

  final TokenGetter _tokenGetter;
  final http.Client _client;

  /// CloudBase SDK 已初始化时，所有 JSON API（含 base64 上传）走云函数。
  bool get _viaCloudbase => CloudbaseGate.app != null;

  Map<String, String> _headersForMode(ApiAuthMode mode) {
    switch (mode) {
      case ApiAuthMode.none:
        return _jsonHeaders(auth: false);
      case ApiAuthMode.bare:
        return <String, String>{};
      case ApiAuthMode.ifPresent:
        return _jsonHeaders(auth: true);
      case ApiAuthMode.required:
        return _authOnlyHeaders();
    }
  }

  Future<({Map<String, dynamic> j, int status})> _requestSpring({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? body,
    required ApiAuthMode authMode,
  }) async {
    if (_viaCloudbase) {
      return CloudbaseApiProxy.request(
        method: method,
        path: path,
        query: query,
        body: body,
        authMode: authMode,
        tokenGetter: _tokenGetter,
      );
    }
    final headers = _headersForMode(authMode);
    final uri = _u(path, query);
    final encoded = body != null ? jsonEncode(body) : null;
    late final http.Response res;
    switch (method.toUpperCase()) {
      case 'GET':
        res = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        res = await _client.post(uri, headers: headers, body: encoded);
        break;
      case 'PUT':
        res = await _client.put(uri, headers: headers, body: encoded);
        break;
      case 'PATCH':
        res = await _client.patch(uri, headers: headers, body: encoded);
        break;
      case 'DELETE':
        res = await _client.delete(uri, headers: headers);
        break;
      default:
        throw ApiException('不支持的 HTTP 方法: $method');
    }
    final j = await _decodeJson(res);
    return (j: j, status: res.statusCode);
  }

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

  static String networkUnreachableMessage() {
    if (CloudbaseGate.app != null) {
      return '无法连接云开发或后端。请部署云函数 ${AppConfig.cloudbaseFunctionName}，并在控制台配置 DATABASE_URL、S3 等环境变量。';
    }
    if (AppConfig.cloudbaseEnvId.isNotEmpty) {
      final err = CloudbaseGate.lastInitError;
      if (err != null && err.isNotEmpty) {
        return 'CloudBase 初始化失败：$err。请检查 CLOUDBASE_ACCESS_KEY、环境 ID 与网络。';
      }
      return 'CloudBase 尚未初始化成功。请重启应用后重试；若仍失败请检查 CLOUDBASE_ACCESS_KEY 与环境配置。';
    }
    return '无法连接服务器（${AppConfig.apiBaseUrl}）。请配置 CLOUDBASE_ENV_ID 使用云函数；或设置 API_BASE_URL 指向兼容的 HTTP 服务。';
  }

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
  Future<String?> authSendCode(String phone, {String type = 'login'}) async {
    try {
      final r = await _requestSpring(
        method: 'POST',
        path: '/api/v1/auth/send-code',
        body: {'phone': phone, 'type': type},
        authMode: ApiAuthMode.none,
      );
      if (r.status >= 400 || r.j['success'] != true) {
        throw ApiException(
          r.j['error']?.toString() ?? '发送验证码失败',
          r.status,
        );
      }
      final devCode = r.j['_dev_code']?.toString();
      return (devCode != null && devCode.isNotEmpty) ? devCode : null;
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
      final r = await _requestSpring(
        method: 'POST',
        path: '/api/v1/auth/login/phone',
        body: {'phone': phone, 'code': code},
        authMode: ApiAuthMode.none,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '登录失败', r.status);
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

  Future<({UserModel user, String token})> authLoginCloudbasePhone(
      String phone) async {
    try {
      final r = await _requestSpring(
        method: 'POST',
        path: '/api/v1/auth/login/cloudbase',
        body: {'phone': phone},
        authMode: ApiAuthMode.none,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '登录失败', r.status);
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

  Future<({UserModel user, String token})> authLoginOauth({
    required String provider,
    required String code,
  }) async {
    try {
      final r = await _requestSpring(
        method: 'POST',
        path: '/api/v1/auth/login/oauth',
        body: {'provider': provider, 'code': code},
        authMode: ApiAuthMode.none,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '第三方登录失败', r.status);
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
    final r = await _requestSpring(
      method: 'POST',
      path: '/api/v1/auth/logout',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '退出失败', r.status);
    }
  }

  Future<UserModel> authMe() async {
    final r = await _requestSpring(
      method: 'GET',
      path: '/api/v1/auth/me',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '获取用户失败', r.status);
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
    int? isoMin,
    int? isoMax,
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
      if (isoMin != null) q['iso_min'] = '$isoMin';
      if (isoMax != null) q['iso_max'] = '$isoMax';

      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/photos',
        query: q,
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载失败', r.status);
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
    String? sort,
  }) async {
    return _guardNetwork(() async {
      final query = <String, String>{'page': '$page', 'limit': '$limit'};
      if (sort != null && sort.isNotEmpty) {
        query['sort'] = sort;
      }
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/photos/my',
        query: query,
        authMode: ApiAuthMode.required,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载失败', r.status);
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
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/photos/favorites',
        query: {'page': '$page', 'limit': '$limit'},
        authMode: ApiAuthMode.required,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载失败', r.status);
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

  /// 我点过赞的作品（按点赞时间倒序）。
  Future<({List<PhotoListItem> photos, Pagination pagination})> photosLikedByMe({
    int page = 1,
    int limit = 20,
  }) async {
    return _guardNetwork(() async {
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/photos/liked-by-me',
        query: {'page': '$page', 'limit': '$limit'},
        authMode: ApiAuthMode.required,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载失败', r.status);
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
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/photos/$id',
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载失败', r.status);
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
    final r = await _requestSpring(
      method: 'POST',
      path: '/api/v1/photos',
      body: body,
      authMode: ApiAuthMode.ifPresent,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '发布失败', r.status);
    }
  }

  Future<bool> photoToggleLike(int id) async {
    final r = await _requestSpring(
      method: 'POST',
      path: '/api/v1/photos/$id/like',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '操作失败', r.status);
    }
    final data = j['data'] as Map<String, dynamic>? ?? {};
    return data['is_liked'] == true;
  }

  Future<bool> photoToggleFavorite(int id) async {
    final r = await _requestSpring(
      method: 'POST',
      path: '/api/v1/photos/$id/favorite',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '操作失败', r.status);
    }
    final data = j['data'] as Map<String, dynamic>? ?? {};
    return data['is_favorited'] == true;
  }

  Future<void> photoAddComment(int id, String content) async {
    final r = await _requestSpring(
      method: 'POST',
      path: '/api/v1/photos/$id/comments',
      body: {'content': content},
      authMode: ApiAuthMode.ifPresent,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '评论失败', r.status);
    }
  }

  Future<void> photoDelete(int id) async {
    final r = await _requestSpring(
      method: 'DELETE',
      path: '/api/v1/photos/$id',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '删除失败', r.status);
    }
  }

  // --- Upload ---
  static String _basename(String p) {
    final n = p.replaceAll('\\', '/');
    final i = n.lastIndexOf('/');
    return i < 0 ? n : n.substring(i + 1);
  }

  static String _guessImageContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  Future<Map<String, dynamic>> uploadImage(String filePath) async {
    if (_viaCloudbase) {
      final name = _basename(filePath);
      final b64 = base64Encode(await File(filePath).readAsBytes());
      final r = await _requestSpring(
        method: 'POST',
        path: '/api/v1/upload/image',
        body: {
          'file_base64': b64,
          'filename': name,
          'content_type': _guessImageContentType(name),
        },
        authMode: ApiAuthMode.required,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '上传失败', r.status);
      }
      return Map<String, dynamic>.from(j['data'] as Map);
    }
    final uri = _u('/api/v1/upload/image');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authOnlyHeaders());
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    final j = await _decodeJson(res);
    if (res.statusCode >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '上传失败', res.statusCode);
    }
    return Map<String, dynamic>.from(j['data'] as Map);
  }

  // --- Users ---
  Future<UserModel> usersMe() async {
    final r = await _requestSpring(
      method: 'GET',
      path: '/api/v1/users/me',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '获取资料失败', r.status);
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
    final r = await _requestSpring(
      method: 'PATCH',
      path: '/api/v1/users/me',
      body: body,
      authMode: ApiAuthMode.ifPresent,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '更新失败', r.status);
    }
    return UserModel.fromJson(Map<String, dynamic>.from(j['data'] as Map));
  }

  /// 公开用户资料（含 `is_following`，未登录时为 false）。
  Future<UserModel> usersPublic(int userId) async {
    return _guardNetwork(() async {
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/users/$userId',
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '用户不存在', r.status);
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
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/users/$userId/photos',
        query: {'page': '$page', 'limit': '$limit'},
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '加载作品失败', r.status);
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

  /// 用户拍摄足迹：按地点聚合，含 `photos` 缩略列表。
  Future<List<Map<String, dynamic>>> usersFootprint(int userId) async {
    return _guardNetwork(() async {
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/users/$userId/footprint',
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '足迹加载失败', r.status);
      }
      final data = j['data'] as List<dynamic>? ?? <dynamic>[];
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  /// 切换关注，返回当前是否已关注。
  Future<bool> usersFollowToggle(int userId) async {
    return _guardNetwork(() async {
      final r = await _requestSpring(
        method: 'POST',
        path: '/api/v1/users/$userId/follow',
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '操作失败', r.status);
      }
      final data = j['data'] as Map<String, dynamic>? ?? {};
      return data['is_following'] == true;
    });
  }

  /// 关注我的用户（粉丝列表）。
  Future<List<UserModel>> usersMyFollowers() async {
    final r = await _requestSpring(
      method: 'GET',
      path: '/api/v1/users/me/followers',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '加载失败', r.status);
    }
    final raw = j['data'] as List<dynamic>? ?? [];
    return raw
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 我关注的用户列表。
  Future<List<UserModel>> usersMyFollowing() async {
    final r = await _requestSpring(
      method: 'GET',
      path: '/api/v1/users/me/following',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '加载失败', r.status);
    }
    final raw = j['data'] as List<dynamic>? ?? [];
    return raw
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    if (_viaCloudbase) {
      final name = _basename(filePath);
      final b64 = base64Encode(await File(filePath).readAsBytes());
      final r = await _requestSpring(
        method: 'POST',
        path: '/api/v1/upload/avatar',
        body: {
          'file_base64': b64,
          'filename': name,
          'content_type': _guessImageContentType(name),
        },
        authMode: ApiAuthMode.required,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '上传失败', r.status);
      }
      return Map<String, dynamic>.from(j['data'] as Map);
    }
    final uri = _u('/api/v1/upload/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authOnlyHeaders());
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await _client.send(request);
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
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/map/photos',
        query: {
          'lat': '$lat',
          'lng': '$lng',
          'radius': radiusKm,
        },
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '地图数据失败', r.status);
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
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/map/popular-spots',
        authMode: ApiAuthMode.bare,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '热门机位失败', r.status);
      }
      final raw = j['data'];
      if (raw is! List) return <Map<String, dynamic>>[];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  // --- Spots ---
  Future<List<Map<String, dynamic>>> spotsMy() async {
    final r = await _requestSpring(
      method: 'GET',
      path: '/api/v1/spots/my',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '机位列表失败', r.status);
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
    final r = await _requestSpring(
      method: 'POST',
      path: '/api/v1/spots',
      body: body,
      authMode: ApiAuthMode.ifPresent,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '保存失败', r.status);
    }
  }

  Future<void> spotsUnlink(int spotId) async {
    final r = await _requestSpring(
      method: 'DELETE',
      path: '/api/v1/spots/$spotId',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '删除失败', r.status);
    }
  }

  // --- Equipment ---
  Future<List<Map<String, dynamic>>> equipmentForUser(int userId) async {
    final r = await _requestSpring(
      method: 'GET',
      path: '/api/v1/equipment/user/$userId',
      authMode: ApiAuthMode.bare,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '器材加载失败', r.status);
    }
    final data = j['data'] as Map<String, dynamic>? ?? {};
    final list = data['equipment'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> equipmentRemoveFromUser(int userId, int equipmentId) async {
    final r = await _requestSpring(
      method: 'DELETE',
      path: '/api/v1/equipment/user/$userId/$equipmentId',
      authMode: ApiAuthMode.required,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '移除失败', r.status);
    }
  }

  Future<List<Map<String, dynamic>>> equipmentCatalog() async {
    final r = await _requestSpring(
      method: 'GET',
      path: '/api/v1/equipment',
      authMode: ApiAuthMode.bare,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '目录加载失败', r.status);
    }
    final data = j['data'] as Map<String, dynamic>? ?? {};
    final list = data['equipment'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> equipmentAddToUser(int userId, int equipmentId) async {
    final r = await _requestSpring(
      method: 'POST',
      path: '/api/v1/equipment/user/$userId',
      body: {'equipment_id': equipmentId},
      authMode: ApiAuthMode.ifPresent,
    );
    final j = r.j;
    if (r.status >= 400 || j['success'] != true) {
      throw ApiException(j['error']?.toString() ?? '添加失败', r.status);
    }
  }

  // --- 拍摄计划（shoot_plans） ---
  Future<List<PlanItem>> shootPlansList() async {
    return _guardNetwork(() async {
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/shoot-plans',
        authMode: ApiAuthMode.required,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '计划列表失败', r.status);
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
      final r = await _requestSpring(
        method: 'PUT',
        path: '/api/v1/shoot-plans',
        body: body,
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '保存计划失败', r.status);
      }
      return PlanItem.fromServerJson(Map<String, dynamic>.from(j['data'] as Map));
    });
  }

  Future<void> shootPlanPatchDone(int planId, bool done) async {
    return _guardNetwork(() async {
      final r = await _requestSpring(
        method: 'PATCH',
        path: '/api/v1/shoot-plans/$planId',
        body: {'done': done},
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '更新计划失败', r.status);
      }
    });
  }

  Future<void> shootPlanDelete(int planId) async {
    return _guardNetwork(() async {
      final r = await _requestSpring(
        method: 'DELETE',
        path: '/api/v1/shoot-plans/$planId',
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '删除计划失败', r.status);
      }
    });
  }

  // --- 挑战 ---
  Future<List<ChallengeItem>> challengesList() async {
    return _guardNetwork(() async {
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/challenges',
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '挑战列表失败', r.status);
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
      final r = await _requestSpring(
        method: 'GET',
        path: '/api/v1/challenges/$challengeId',
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '挑战详情失败', r.status);
      }
      return ChallengeItem.fromJson(Map<String, dynamic>.from(j['data'] as Map));
    });
  }

  Future<void> challengeJoin(int challengeId, {int? photoId}) async {
    return _guardNetwork(() async {
      final body = <String, dynamic>{if (photoId != null) 'photo_id': photoId};
      final r = await _requestSpring(
        method: 'POST',
        path: '/api/v1/challenges/$challengeId/join',
        body: body,
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? '参与挑战失败', r.status);
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
      final r = await _requestSpring(
        method: 'POST',
        path: '/api/v1/ai/publish-assist',
        body: body,
        authMode: ApiAuthMode.ifPresent,
      );
      final j = r.j;
      if (r.status >= 400 || j['success'] != true) {
        throw ApiException(j['error']?.toString() ?? 'AI 生成失败', r.status);
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
