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
import 'package:tongjing/services/photo_state_sync_bus.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/utils/photo_recipe_display.dart';
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
  final _syncBus = PhotoStateSyncBus.instance;
  List<PhotoListItem> _list = [];
  bool _loading = true;

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              '登录后可管理你的作品',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => context.push('/login'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.kleinBlue,
              ),
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(
          Icons.photo_library_outlined,
          size: 54,
          color: AppColors.textMuted,
        ),
        SizedBox(height: 12),
        Center(
          child: Text(
            '暂无作品',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  @override
  /// 组件初始化阶段执行一次，用于准备首屏数据与监听器。
  ///
  /// 方法：`initState`。
  void initState() {
    super.initState();
    _syncBus.addListener(_onPhotoStateSync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _syncBus.removeListener(_onPhotoStateSync);
    super.dispose();
  }

  void _onPhotoStateSync() {
    final e = _syncBus.lastEvent;
    if (!mounted || e == null) return;
    final idx = _list.indexWhere((x) => x.id == e.photoId);
    if (idx < 0) return;
    final b = _list[idx];
    setState(() {
      _list[idx] = b.copyWith(
        isLiked: e.isLiked ?? b.isLiked,
        likesCount: e.likesCount ?? b.likesCount,
        isFavorited: e.isFavorited ?? b.isFavorited,
        favoritesCount: e.favoritesCount ?? b.favoritesCount,
      );
    });
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
    final router = GoRouter.of(context);
    final ids = dedupePhotoIdsInOrder(_list.map((e) => e.id));
    final ix = ids.indexOf(p.id);
    final dynamic r = ids.length > 1
        ? await router.push(
            '/photo/${p.id}',
            extra: PhotoGalleryExtra(
              photoIds: ids,
              initialIndex: ix >= 0 ? ix : 0,
            ),
          )
        : await router.push('/photo/${p.id}');
    if (!mounted) return;
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('我的作品'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
        ),
        body: _buildLoginPrompt(),
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
                  ? _buildEmptyState()
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
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: p.imageUrl,
                                  fit: BoxFit.cover,
                                  httpHeaders: kRemoteImageHttpHeaders,
                                ),
                                PhotoGridCaptionOverlay(photo: p),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
