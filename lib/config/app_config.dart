// 文件说明：配置代码，负责集中管理可变环境参数。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

import 'app_config_stub.dart'
    if (dart.library.io) 'app_config_io.dart' as impl;

// 后端 API 根地址。
//
// 未设置 `API_BASE_URL` 时：Android 默认 `http://10.0.2.2:9091`，其余平台默认 `127.0.0.1`。
// 真机：`flutter run --dart-define=API_BASE_URL=http://<电脑局域网IP>:9091`
class AppConfig {
  AppConfig._();

  static const String _apiBaseUrlEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl =>
      _apiBaseUrlEnv.isNotEmpty ? _apiBaseUrlEnv : impl.defaultApiBaseUrl();

  /// 是否启用本地 Mock 数据。
  ///
  /// 使用方式：
  /// `flutter run --dart-define=USE_MOCK_DATA=true`
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: false,
  );
}
