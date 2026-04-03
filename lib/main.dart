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
import 'package:tongjing/providers/settings_provider.dart';
import 'package:tongjing/router/app_router.dart';
import 'package:tongjing/services/cloudbase_gate.dart';
import 'package:tongjing/services/wechat_auth_gate.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TongjingBootstrapApp());
}

class _BootstrapReady {
  const _BootstrapReady({
    required this.auth,
    required this.settings,
    required this.router,
  });

  final AuthNotifier auth;
  final SettingsNotifier settings;
  final GoRouter router;
}

class TongjingBootstrapApp extends StatefulWidget {
  const TongjingBootstrapApp({super.key});

  @override
  State<TongjingBootstrapApp> createState() => _TongjingBootstrapAppState();
}

class _TongjingBootstrapAppState extends State<TongjingBootstrapApp> {
  late Future<_BootstrapReady> _ready = _bootstrap();

  Future<_BootstrapReady> _bootstrap() async {
    await CloudbaseGate.ensureInitialized();
    if (AppConfig.enableWechatLogin) {
      await WechatAuthGate.ensureInitialized();
    }
    debugPrint(
      'CloudBase init status: env=${AppConfig.cloudbaseEnvId}, appReady=${CloudbaseGate.app != null}, error=${CloudbaseGate.lastInitError}',
    );
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthNotifier(prefs);
    await auth.init();
    final settings = SettingsNotifier();
    await settings.init();
    final router = createAppRouter(auth);
    return _BootstrapReady(auth: auth, settings: settings, router: router);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapReady>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          return TongjingApp(
            auth: snap.data!.auth,
            settings: snap.data!.settings,
            router: snap.data!.router,
          );
        }
        if (snap.connectionState == ConnectionState.done && snap.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF0E2A7B),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '同镜',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '启动失败，请重试',
                      style: TextStyle(color: Color(0xFFDDE3F6)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _ready = _bootstrap();
                        });
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Color(0xFF0E2A7B),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '同镜',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 14),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFFDDE3F6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `TongjingApp`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class TongjingApp extends StatelessWidget {
  const TongjingApp({
    super.key,
    required this.auth,
    required this.settings,
    required this.router,
  });

  final AuthNotifier auth;
  final SettingsNotifier settings;
  final GoRouter router;

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: auth),
        ChangeNotifierProvider<SettingsNotifier>.value(value: settings),
      ],
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
