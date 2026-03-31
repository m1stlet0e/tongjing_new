// 文件说明：应用启动入口，负责初始化本地缓存、鉴权状态与全局路由。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 应用启动入口：完成依赖初始化、鉴权状态恢复并挂载全局路由。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/router/app_router.dart';
import 'package:tongjing/services/cloudbase_gate.dart';
import 'package:tongjing/services/wechat_auth_gate.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CloudbaseGate.ensureInitialized();
  await WechatAuthGate.ensureInitialized();
  debugPrint(
    'CloudBase init status: env=${AppConfig.cloudbaseEnvId}, appReady=${CloudbaseGate.app != null}, error=${CloudbaseGate.lastInitError}',
  );
  final prefs = await SharedPreferences.getInstance();
  final auth = AuthNotifier(prefs);
  await auth.init();
  final router = createAppRouter(auth);
  runApp(TongjingApp(auth: auth, router: router));
}

/// `TongjingApp`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class TongjingApp extends StatelessWidget {
  const TongjingApp({
    super.key,
    required this.auth,
    required this.router,
  });

  final AuthNotifier auth;
  final GoRouter router;

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthNotifier>.value(
      value: auth,
      child: MaterialApp.router(
        title: '同镜',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.kleinBlue,
            primary: AppColors.kleinBlue,
          ),
          useMaterial3: true,
          // 去掉水波纹等待，点击后 UI 立即反馈（仍保留 onPressed 逻辑）。
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        routerConfig: router,
      ),
    );
  }
}
