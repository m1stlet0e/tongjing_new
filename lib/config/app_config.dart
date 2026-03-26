// 文件说明：配置代码，负责集中管理可变环境参数。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 后端 API 根地址。
//
// 构建示例：
// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:9091`（Android 模拟器访问本机）
// `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:9091`（真机访问局域网电脑）
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:9091',
  );
}
