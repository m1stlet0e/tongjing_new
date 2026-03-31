// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`my_equipment_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/theme/app_colors.dart';

/// `MyEquipmentScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class MyEquipmentScreen extends StatefulWidget {
  const MyEquipmentScreen({super.key});

  @override
  State<MyEquipmentScreen> createState() => _MyEquipmentScreenState();
}

/// `_MyEquipmentScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _MyEquipmentScreenState extends State<MyEquipmentScreen> {
  List<Map<String, dynamic>> _items = [];
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
    if (!auth.isAuthenticated) return;
    setState(() => _loading = true);
    try {
      final list = await auth.api.equipmentForUser(auth.user!.id);
      setState(() => _items = list);
    } catch (_) {
      setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_name`。
  String _name(Map<String, dynamic> e) {
    final b = e['brand']?.toString() ?? '';
    final m = e['model']?.toString() ?? '';
    return '$b $m'.trim();
  }

  Future<void> _remove(Map<String, dynamic> e) async {
    final auth = context.read<AuthNotifier>();
    final id = (e['id'] as num?)?.toInt();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('移除器材'),
        content: Text('从装备库移除「${_name(e)}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('移除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await auth.api.equipmentRemoveFromUser(auth.user!.id, id);
      await _load();
    } on ApiException catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
      }
    }
  }

  Future<void> _addFromCatalog() async {
    final auth = context.read<AuthNotifier>();
    List<Map<String, dynamic>> catalog = [];
    try {
      catalog = await auth.api.equipmentCatalog();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加载器材目录失败')));
      }
      return;
    }
    catalog = catalog.take(80).toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, scroll) {
            return ListView.builder(
              controller: scroll,
              itemCount: catalog.length,
              itemBuilder: (context, i) {
                final e = catalog[i];
                final id = (e['id'] as num?)?.toInt() ?? 0;
                return ListTile(
                  title: Text(_name(e)),
                  subtitle: Text(e['type']?.toString() ?? ''),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await auth.api.equipmentAddToUser(auth.user!.id, id);
                      await _load();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已添加')));
                      }
                    } on ApiException catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
                      }
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
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
        appBar: AppBar(title: const Text('我的器材')),
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
        title: const Text('我的器材'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(onPressed: _addFromCatalog, icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('暂无器材，点击右上角添加')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final e = _items[i];
                        final type = e['type']?.toString() ?? '';
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              type == 'camera' ? Icons.camera_alt : Icons.camera_outlined,
                              color: AppColors.kleinBlue,
                            ),
                            title: Text(_name(e)),
                            subtitle: Text(type),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _remove(e),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
