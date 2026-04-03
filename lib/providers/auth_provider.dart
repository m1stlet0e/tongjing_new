// 文件说明：状态管理层代码，负责全局状态维护与变更通知。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 状态管理模块：维护全局会话状态并向界面层分发登录态变更。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongjing/models/user_model.dart';
import 'package:tongjing/services/api_service.dart';

/// `AuthNotifier`：状态通知器，负责维护内存状态并向监听方广播变更。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._prefs) {
    api = ApiService(() => _token);
  }

  final SharedPreferences _prefs;
  late final ApiService api;

  static const _kToken = 'auth_token';
  static const _kUser = 'user_info';

  /// API 调用超时时间（10秒）
  static const Duration _apiTimeout = Duration(seconds: 10);

  String? _token;
  UserModel? _user;
  bool _bootstrapping = true;
  String? _initError; // 记录初始化错误信息

  String? get token => _token;
  UserModel? get user => _user;
  bool get isAuthenticated =>
      _token != null && _token!.isNotEmpty && _user != null;
  bool get bootstrapping => _bootstrapping;
  String? get initError => _initError;

  Future<void> init() async {
    _bootstrapping = true;
    _initError = null;
    notifyListeners();
    _token = _prefs.getString(_kToken);
    final raw = _prefs.getString(_kUser);
    if (raw != null) {
      try {
        _user = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _user = null;
      }
    }
    if (_token != null && _token!.isNotEmpty) {
      try {
        // 添加超时保护
        _user = await api.authMe().timeout(
          _apiTimeout,
          onTimeout: () {
            throw ApiException('网络超时，请检查网络连接');
          },
        );
        await _prefs.setString(_kUser, jsonEncode(_user!.toJson()));
        _initError = null;
      } catch (e) {
        // API 调用失败时，保留本地缓存的用户信息，允许用户正常使用
        debugPrint('authMe failed: $e, keeping cached user');
        _initError = e is ApiException ? e.message : '登录状态验证失败';
        // 不再强制退出，保留 token 让用户可以继续使用
        // 如果后续 API 调用失败会有更明确的错误提示
      }
    }
    _bootstrapping = false;
    notifyListeners();
  }

  Future<void> login(UserModel u, String t) async {
    _token = t;
    _user = u;
    await _prefs.setString(_kToken, t);
    await _prefs.setString(_kUser, jsonEncode(u.toJson()));
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    try {
      _user = await api.authMe();
      await _prefs.setString(_kUser, jsonEncode(_user!.toJson()));
      notifyListeners();
    } catch (_) {
      // 忽略网络错误
    }
  }

  Future<void> updateLocalUser(UserModel u) async {
    _user = u;
    await _prefs.setString(_kUser, jsonEncode(u.toJson()));
    notifyListeners();
  }

  Future<void> logout({bool clearRemote = true}) async {
    if (clearRemote && _token != null) {
      try {
        await api.authLogout();
      } catch (_) {}
    }
    _token = null;
    _user = null;
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
    notifyListeners();
  }
}
