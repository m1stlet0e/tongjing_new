// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`my_plans_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/theme/app_colors.dart';

/// `MyPlansScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({super.key});

  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
}

/// `_MyPlansScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _MyPlansScreenState extends State<MyPlansScreen> {
  List<_PlanRow> _plans = [];
  bool _loading = true;

  @override
  /// 组件初始化阶段执行一次，用于准备首屏数据与监听器。
  ///
  /// 方法：`initState`。
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    // 原 RN 调用不存在的 /plans/my，此处使用与「计划」页一致的本地示例数据
    await Future<void>.delayed(const Duration(milliseconds: 300));
    setState(() {
      _plans = [
        _PlanRow('外滩夜景拍摄', '上海·外滩观景台', '2025-01-18 17:30'),
        _PlanRow('世纪公园晨雾', '上海·世纪公园', '2025-01-20 06:00'),
      ];
      _loading = false;
    });
  }

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的计划')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('请先登录'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的计划'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _plans.isEmpty
                  ? ListView(children: const [SizedBox(height: 120), Center(child: Text('暂无计划'))])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _plans.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = _plans[i];
                        return Card(
                          child: ListTile(
                            title: Text(p.title),
                            subtitle: Text('${p.location}\n${p.time}', maxLines: 2),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// `_PlanRow`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _PlanRow {
  _PlanRow(this.title, this.location, this.time);
  final String title;
  final String location;
  final String time;
}
