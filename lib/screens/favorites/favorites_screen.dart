// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`favorites_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/photo_state_sync_bus.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/utils/photo_recipe_display.dart';
import 'package:tongjing/utils/remote_image.dart';

/// `FavoritesScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

/// `_FavoritesScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _FavoritesScreenState extends State<FavoritesScreen> {
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
              Icons.bookmark_border_rounded,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              '登录后可查看收藏作品',
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
          Icons.bookmark_border_rounded,
          size: 54,
          color: AppColors.textMuted,
        ),
        SizedBox(height: 12),
        Center(
          child: Text(
            '暂无收藏',
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
    setState(() {
      if (idx >= 0) {
        final before = _list[idx];
        final next = before.copyWith(
          isLiked: e.isLiked ?? before.isLiked,
          likesCount: e.likesCount ?? before.likesCount,
          isFavorited: e.isFavorited ?? before.isFavorited,
          favoritesCount: e.favoritesCount ?? before.favoritesCount,
        );
        if (e.isFavorited == false) {
          _list.removeAt(idx);
        } else {
          _list[idx] = next;
        }
        return;
      }
      if (e.isFavorited == true && e.photo != null) {
        _list.insert(0, e.photo!);
        return;
      }
      if (e.isFavorited == true) {
        _load();
      } else {
        // no-op
      }
    });
  }

  Future<void> _load() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) return;
    setState(() => _loading = true);
    try {
      final r = await auth.api.photosFavorites();
      setState(() => _list = r.photos);
    } catch (_) {
      setState(() => _list = []);
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('收藏'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
        ),
        body: _buildLoginPrompt(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('收藏'),
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
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _list.length,
                      itemBuilder: (context, i) {
                        final p = _list[i];
                        return GestureDetector(
                          onTap: () async {
                            await context.push('/photo/${p.id}');
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
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
