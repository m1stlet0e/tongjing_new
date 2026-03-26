// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`profile_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/models/user_model.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/theme/app_colors.dart';

/// `ProfileScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// `_ProfileScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _profile;
  List<PhotoListItem> _photos = [];
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
      final me = await auth.api.usersMe();
      final my = await auth.api.photosMy(limit: 20);
      setState(() {
        _profile = me;
        _photos = my.photos;
      });
    } on ApiException catch (_) {
      setState(() => _profile = auth.user);
    } catch (_) {
      setState(() => _profile = auth.user);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定退出当前账号？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AuthNotifier>().logout();
    }
  }

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    if (!auth.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline, size: 56, color: AppColors.kleinBlue),
                  const SizedBox(height: 16),
                  const Text('登录后查看个人中心', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('记录你的摄影足迹，发现更多精彩',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push('/login'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.kleinBlue),
                    child: const Text('立即登录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_loading && _profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final u = _profile ?? auth.user!;
    final avatar = u.avatarUrl ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(u.username)}&background=002FA7&color=fff';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.kleinBlue,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.push('/settings'),
                            icon: const Icon(Icons.settings_outlined),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        radius: 44,
                        backgroundImage: CachedNetworkImageProvider(avatar),
                      ),
                      const SizedBox(height: 12),
                      Text(u.username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(u.bio ?? '还没有个人简介',
                          style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _stat('作品', u.photosCount ?? _photos.length),
                          _stat('粉丝', u.followersCount ?? 0),
                          _stat('关注', u.followingCount ?? 0),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _action(Icons.favorite_border, '收藏', () => context.push('/favorites'))),
                          Expanded(child: _action(Icons.calendar_today_outlined, '计划', () => context.push('/my-plans'))),
                          Expanded(child: _action(Icons.map_outlined, '机位', () => context.push('/my-spots'))),
                          Expanded(child: _action(Icons.emoji_events_outlined, '挑战', () => context.push('/challenges'))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('我的作品', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          TextButton(onPressed: () => context.push('/my-works'), child: const Text('查看全部')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_photos.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('还没有发布作品')),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i >= _photos.length) return null;
                        final p = _photos[i];
                        return GestureDetector(
                          onTap: () => context.push('/photo/${p.id}'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(imageUrl: p.imageUrl, fit: BoxFit.cover),
                          ),
                        );
                      },
                      childCount: _photos.length > 6 ? 6 : _photos.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_stat`。
  Widget _stat(String label, int v) {
    return Column(
      children: [
        Text('$v', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_action`。
  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: AppColors.kleinBlue),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
