import 'dart:io' show Platform;

/// 非 Web 平台：Android 模拟器访问宿主机用 10.0.2.2。
String defaultApiBaseUrl() =>
    Platform.isAndroid ? 'http://10.0.2.2:9091' : 'http://127.0.0.1:9091';
