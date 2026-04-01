// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`my_works_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/router/photo_gallery_extra.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/utils/remote_image.dart';

/// `MyWorksScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class MyWorksScreen extends StatefulWidget {
  const MyWorksScreen({super.key});

  @override
  State<MyWorksScreen> createState() => _MyWorksScreenState();
}

/// `_MyWorksScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _MyWorksScreenState extends State<MyWorksScreen> {
  List<PhotoListItem> _list = [];
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
      final r = await auth.api.photosMy(limit: 100);
      setState(() => _list = r.photos);
    } catch (_) {
      setState(() => _list = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPhotoInGallery(PhotoListItem p) async {
    final ids = dedupePhotoIdsInOrder(_list.map((e) => e.id));
    final ix = ids.indexOf(p.id);
    final dynamic r = ids.length > 1
        ? await context.push(
            '/photo/${p.id}',
            extra: PhotoGalleryExtra(
              photoIds: ids,
              initialIndex: ix >= 0 ? ix : 0,
            ),
          )
        : await context.push('/photo/${p.id}');
    if (!context.mounted) return;
    if (r == true) await _load();
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
        appBar: AppBar(title: const Text('我的作品')),
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
        title: const Text('我的作品'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _list.isEmpty
                  ? ListView(children: const [SizedBox(height: 120), Center(child: Text('暂无作品'))])
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1,
                      ),
                      itemCount: _list.length,
                      itemBuilder: (context, i) {
                        final p = _list[i];
                        return GestureDetector(
                          onTap: () => _openPhotoInGallery(p),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: p.imageUrl,
                              fit: BoxFit.cover,
                              httpHeaders: kRemoteImageHttpHeaders,
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
