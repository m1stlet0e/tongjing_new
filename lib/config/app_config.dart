// 文件说明：配置代码，负责集中管理可变环境参数。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

import 'app_config_stub.dart'
    if (dart.library.io) 'app_config_io.dart' as impl;

// 后端 API 根地址（仅当未初始化 CloudBase SDK 时使用：直连 HTTP，需自行提供与 `/api/v1/*` 契约一致的服务）。
//
// 未设置 `API_BASE_URL` 时：Android 默认 `http://10.0.2.2:9091`，其余平台默认 `127.0.0.1:9091`。
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

  /// 地图底图 XYZ 模板，需含 `{z}`、`{x}`、`{y}`。
  ///
  /// 默认使用 `tile.openstreetmap.de` 镜像（与 OSM 同源数据）。国内直连
  /// `tile.openstreetmap.org` 常超时或被墙，可改用本项或自行换高德/天地图等（需合规与 key）。
  ///
  /// 示例：`flutter run --dart-define=MAP_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png`
  static const String mapTileUrlTemplate = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
  );

  // --- 腾讯云 CloudBase（原生端用 SDK + callFunction，管理环境/部署请配 .cursor/mcp.json 中 CloudBase MCP）---
  /// 云开发环境 ID，控制台「环境设置」中可见。未配置时不初始化 SDK，此时 JSON 请求走 [apiBaseUrl]。
  static const String cloudbaseEnvId = String.fromEnvironment(
    'CLOUDBASE_ENV_ID',
    defaultValue: 'dev-1-2gpyqdj67e1e109d',
  );

  /// 地域，如 `ap-shanghai`、`ap-guangzhou`、`ap-singapore`。
  static const String cloudbaseRegion = String.fromEnvironment(
    'CLOUDBASE_REGION',
    defaultValue: 'ap-shanghai',
  );

  /// 可公开的前端访问密钥（Publishable Key），按控制台说明配置；可留空。
  static const String cloudbaseAccessKey = String.fromEnvironment(
    'CLOUDBASE_ACCESS_KEY',
    defaultValue: '',
  );

  /// 与控制台创建的云函数名一致，默认 `tongjing_api`。
  static const String cloudbaseFunctionName = String.fromEnvironment(
    'CLOUDBASE_FUNCTION_NAME',
    defaultValue: 'tongjing_api',
  );

  /// 是否启用 CloudBase 原生手机号登录（发码/验码）。
  /// 验码成功后仍会调用业务后端换取同镜业务 token。
  static const bool cloudbaseUseNativeAuth = bool.fromEnvironment(
    'CLOUDBASE_USE_NATIVE_AUTH',
    defaultValue: true,
  );

  /// 微信开放平台 AppID（用于原生微信授权登录）。
  static const String wechatOpenAppId = String.fromEnvironment(
    'WECHAT_OPEN_APP_ID',
    defaultValue: '',
  );

  /// iOS Universal Link（微信开放平台配置项，示例：https://app.example.com/link/）。
  static const String wechatUniversalLink = String.fromEnvironment(
    'WECHAT_UNIVERSAL_LINK',
    defaultValue: '',
  );
}
