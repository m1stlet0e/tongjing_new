// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`my_spots_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/utils/remote_image.dart';

/// `MySpotsScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class MySpotsScreen extends StatefulWidget {
  const MySpotsScreen({super.key});

  @override
  State<MySpotsScreen> createState() => _MySpotsScreenState();
}

/// `_MySpotsScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _MySpotsScreenState extends State<MySpotsScreen> {
  List<Map<String, dynamic>> _spots = [];
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
      final s = await auth.api.spotsMy();
      setState(() => _spots = s);
    } catch (_) {
      setState(() => _spots = []);
    } finally {
      if (mounted) setState(() => _loading = false);
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
        appBar: AppBar(title: const Text('我的机位')),
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
        title: const Text('我的机位'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () => context.push('/add-spot'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-spot'),
        backgroundColor: AppColors.kleinBlue,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _spots.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        const Center(child: Text('暂无机位')),
                        const SizedBox(height: 16),
                        Center(
                          child: FilledButton(
                            onPressed: () => context.push('/add-spot'),
                            child: const Text('添加机位'),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _spots.length,
                      itemBuilder: (context, i) {
                        final s = _spots[i];
                        final name = s['name']?.toString() ?? '未命名';
                        final loc = s['location_name']?.toString() ?? '';
                        final img = s['image_url']?.toString();
                        final id = (s['id'] as num?)?.toInt() ?? 0;
                        return Card(
                          child: ListTile(
                            leading: img != null && img.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CachedNetworkImage(
                                      imageUrl: img,
                                      httpHeaders: kRemoteImageHttpHeaders,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.place, color: AppColors.kleinBlue),
                            title: Text(name),
                            subtitle: Text(loc),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final auth = context.read<AuthNotifier>();
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('取消收藏机位'),
                                    content: const Text('从「我的机位」中移除？'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('移除')),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  try {
                                    await auth.api.spotsUnlink(id);
                                    await _load();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
