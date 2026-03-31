// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`my_plans_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/plan_item.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/plan_store.dart';
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
  final _planStore = PlanStore();
  List<PlanItem> _plans = [];
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
    try {
      final plans = await _planStore.list(auth.api);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = [];
        _loading = false;
      });
    }
  }

  Future<void> _toggleDone(PlanItem item, bool? value) async {
    final auth = context.read<AuthNotifier>();
    final id = item.planId;
    if (id == null) return;
    try {
      await _planStore.setDone(auth.api, id, value == true);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败：$e')),
        );
      }
    }
  }

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    final isLoggedIn =
        context.select<AuthNotifier, bool>((a) => a.isAuthenticated);
    if (!isLoggedIn) {
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
                            subtitle: Text(
                              '${p.location}\n${p.cameraLine}${p.tips == null || p.tips!.isEmpty ? '' : '\n${p.tips}'}',
                              maxLines: 2,
                            ),
                            isThreeLine: true,
                            leading: Checkbox(
                              value: p.done,
                              onChanged: (v) => _toggleDone(p, v),
                            ),
                            onTap: p.photoId > 0
                                ? () async {
                                    await context.push('/photo/${p.photoId}');
                                    if (mounted) await _load();
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
