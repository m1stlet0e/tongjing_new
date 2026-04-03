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
import 'package:tongjing/services/photo_state_sync_bus.dart';
import 'package:tongjing/router/photo_gallery_extra.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/theme/app_spacing.dart';
import 'package:tongjing/theme/app_typography.dart';
import 'package:tongjing/theme/app_shapes.dart';
import 'package:tongjing/utils/remote_image.dart';
import 'package:tongjing/widgets/gear_card.dart';

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
  final _syncBus = PhotoStateSyncBus.instance;
  UserModel? _profile;
  List<PhotoListItem> _photos = [];
  List<Map<String, dynamic>> _gear = [];
  List<Map<String, dynamic>> _footprintRows = [];
  List<PhotoListItem> _favoritePhotos = [];
  bool _loading = true;
  bool _loadingGear = true;
  bool _loadingContent = true;
  int _contentTab = 0;

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
    setState(() {
      final i1 = _photos.indexWhere((x) => x.id == e.photoId);
      if (i1 >= 0) {
        final b = _photos[i1];
        _photos[i1] = b.copyWith(
          isLiked: e.isLiked ?? b.isLiked,
          likesCount: e.likesCount ?? b.likesCount,
          isFavorited: e.isFavorited ?? b.isFavorited,
          favoritesCount: e.favoritesCount ?? b.favoritesCount,
        );
      }
      final i2 = _favoritePhotos.indexWhere((x) => x.id == e.photoId);
      if (i2 >= 0) {
        if (e.isFavorited == false) {
          _favoritePhotos.removeAt(i2);
        } else {
          final b = _favoritePhotos[i2];
          _favoritePhotos[i2] = b.copyWith(
            isLiked: e.isLiked ?? b.isLiked,
            likesCount: e.likesCount ?? b.likesCount,
            isFavorited: e.isFavorited ?? b.isFavorited,
            favoritesCount: e.favoritesCount ?? b.favoritesCount,
          );
        }
      } else if (e.isFavorited == true && e.photo != null) {
        _favoritePhotos.insert(0, e.photo!);
      }
    });
  }

  Future<void> _load() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) return;
    setState(() {
      _loading = true;
      _loadingGear = true;
      _loadingContent = true;
    });
    UserModel? me;
    try {
      me = await auth.api.usersMe();
    } on ApiException catch (_) {
      me = auth.user;
    } catch (_) {
      me = auth.user;
    }
    if (me == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingGear = false;
          _loadingContent = false;
        });
      }
      return;
    }
    final meId = me.id;

    Future<List<PhotoListItem>> loadMyPhotos() async {
      try {
        final my = await auth.api.photosMy(limit: 60);
        return my.photos;
      } catch (_) {
        return <PhotoListItem>[];
      }
    }

    Future<List<Map<String, dynamic>>> loadGear() async {
      try {
        return await auth.api.equipmentForUser(meId);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }

    Future<List<Map<String, dynamic>>> loadFootprints() async {
      try {
        return await auth.api.usersFootprint(meId);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }

    Future<List<PhotoListItem>> loadFavorites() async {
      try {
        final fr = await auth.api.photosFavorites(limit: 60);
        return fr.photos;
      } catch (_) {
        return <PhotoListItem>[];
      }
    }

    final results = await Future.wait<Object>([
      loadMyPhotos(),
      loadGear(),
      loadFootprints(),
      loadFavorites(),
    ]);
    final photos = results[0] as List<PhotoListItem>;
    final gear = results[1] as List<Map<String, dynamic>>;
    final fp = results[2] as List<Map<String, dynamic>>;
    final favs = results[3] as List<PhotoListItem>;

    if (!mounted) return;
    setState(() {
      _profile = me;
      _photos = photos;
      _gear = gear;
      _footprintRows = fp;
      _favoritePhotos = favs;
      _loading = false;
      _loadingGear = false;
      _loadingContent = false;
    });
  }

  Future<void> _openPhotoInGallery(List<PhotoListItem> source, PhotoListItem p) async {
    final ids = dedupePhotoIdsInOrder(source.map((e) => e.id));
    final ix = ids.indexOf(p.id);
    final router = GoRouter.of(context);
    final dynamic r = ids.length > 1
        ? await router.push(
            '/photo/${p.id}',
            extra: PhotoGalleryExtra(
              photoIds: ids,
              initialIndex: ix >= 0 ? ix : 0,
            ),
          )
        : await router.push('/photo/${p.id}');
    if (!context.mounted) return;
    if (r == true) {
      await _load();
    }
  }

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    final canViewProfile =
        context.select<AuthNotifier, bool>((a) => a.isAuthenticated);
    final sessionUser =
        context.select<AuthNotifier, UserModel?>((a) => a.user);

    if (!canViewProfile) {
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

    final u = _profile ?? sessionUser!;

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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.profileHeaderStart, AppColors.kleinBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: AppShapes.radiusXxlAll,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => context.push('/settings'),
                                  icon: const Icon(
                                    Icons.settings_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                            _ProfileAvatar(user: u),
                            AppSpacing.verticalMd,
                            Text(
                              u.username,
                              style: AppTypography.pageTitleSmall.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            AppSpacing.verticalXs,
                            Text(
                              u.bio ?? '还没有个人简介',
                              style: AppTypography.secondary.copyWith(
                                color: AppColors.infoLight,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.spaceEvenly,
                              runSpacing: 10,
                              spacing: 4,
                              children: [
                                _stat(
                                  '赞过',
                                  u.myLikesCount ?? 0,
                                  light: true,
                                  tappable: true,
                                  onTap: () => context.push('/my-liked-photos'),
                                ),
                                _stat(
                                  '粉丝',
                                  u.followersCount ?? 0,
                                  light: true,
                                  tappable: true,
                                  onTap: () => context.push('/my-followers'),
                                ),
                                _stat(
                                  '关注',
                                  u.followingCount ?? 0,
                                  light: true,
                                  tappable: true,
                                  onTap: () => context.push('/my-following'),
                                ),
                                _stat(
                                  '地点',
                                  _footprintRows.length,
                                  light: true,
                                  tappable: true,
                                  onTap: () => context.go('/map'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '我的防潮箱',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                      if (_loadingGear)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 96,
                        child: _gear.isEmpty
                            ? Center(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await context.push('/my-equipment');
                                    if (mounted) _load();
                                  },
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: AppColors.kleinBlue),
                                  label: const Text('添加防潮箱装备'),
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _gear.length,
                                itemBuilder: (context, i) {
                                  final e = _gear[i];
                                  final brand = e['brand']?.toString() ?? '';
                                  final model = e['model']?.toString() ?? '';
                                  final title = '$brand $model'.trim();
                                  final type = e['type']?.toString() ?? '';
                                  return GearCard(title: title.isEmpty ? '器材' : title, type: type);
                                },
                              ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('我的内容', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          TextButton(onPressed: () => context.push('/my-works'), child: const Text('查看更多')),
                        ],
                      ),
                      if (_loadingContent)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      Row(
                        children: [
                          Expanded(child: _contentChip('作品', 0)),
                          Expanded(child: _contentChip('足迹', 1)),
                          Expanded(child: _contentChip('收藏', 2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_contentTab == 1) ..._footprintSlivers(context)
              else if (_contentTab == 2) ..._favoritesSlivers(context)
              else if (_photos.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('还没有发布作品')),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSpacing.xxs,
                      crossAxisSpacing: AppSpacing.xxs,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i >= _photos.length) return null;
                        final p = _photos[i];
                        return GestureDetector(
                          onTap: () => _openPhotoInGallery(_photos, p),
                          child: ClipRRect(
                            borderRadius: AppShapes.radiusXsAll,
                            child: CachedNetworkImage(
                              imageUrl: p.imageUrl,
                              fit: BoxFit.cover,
                              httpHeaders: kRemoteImageHttpHeaders,
                            ),
                          ),
                        );
                      },
                      childCount: _photos.length,
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
  Widget _stat(
    String label,
    int v, {
    bool light = false,
    bool tappable = false,
    VoidCallback? onTap,
  }) {
    final valueStyle = AppTypography.statNumber.copyWith(
      color: light ? Colors.white : AppColors.textPrimary,
    );
    final labelStyle = AppTypography.statLabel.copyWith(
      color: light ? AppColors.infoLight : AppColors.textMuted,
    );
    final col = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$v', style: valueStyle),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: labelStyle,
              ),
            ),
            if (tappable && onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: light ? const Color(0x88FFFFFF) : AppColors.textMuted,
              ),
          ],
        ),
      ],
    );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: col,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShapes.radiusSmAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: col,
        ),
      ),
    );
  }

  List<Widget> _footprintSlivers(BuildContext context) {
    if (_footprintRows.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppShapes.radiusXlAll,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  const Text(
                    '发布作品时填写地点与经纬度后，会按地点聚合展示在这里。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.push('/map'),
                    child: const Text('去地图看看'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        sliver: SliverToBoxAdapter(
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/map'),
              child: const Text('在地图中查看'),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final row = _footprintRows[i];
              final name = row['location_name']?.toString() ?? '未命名地点';
              final cnt = (row['photo_count'] as num?)?.toInt() ?? 0;
              final photos = row['photos'] as List<dynamic>? ?? [];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place, color: AppColors.kleinBlue, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            '$cnt 张',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (photos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 56,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length.clamp(0, 6),
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (context, j) {
                              final ph = photos[j] as Map<String, dynamic>;
                              final id = (ph['id'] as num?)?.toInt() ?? 0;
                              final url = ph['image_url']?.toString() ?? '';
                              return GestureDetector(
                                onTap: () {
                                  if (id > 0) context.push('/photo/$id');
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    httpHeaders: kRemoteImageHttpHeaders,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 56,
                                      height: 56,
                                      color: AppColors.borderLight,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
            childCount: _footprintRows.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _favoritesSlivers(BuildContext context) {
    if (_favoritePhotos.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppShapes.radiusXlAll,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  const Text(
                    '暂无收藏作品',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/favorites'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.kleinBlue),
                    child: const Text('浏览全部收藏'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.xxs,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              if (i >= _favoritePhotos.length) return null;
              final p = _favoritePhotos[i];
              return GestureDetector(
                onTap: () => _openPhotoInGallery(_favoritePhotos, p),
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
            childCount: _favoritePhotos.length,
          ),
        ),
      ),
    ];
  }

  Widget _contentChip(String label, int i) {
    final on = _contentTab == i;
    return InkWell(
      onTap: () => setState(() => _contentTab = i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: on ? AppColors.kleinBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: on ? AppColors.kleinBlue : AppColors.textMuted,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 头像：ui-avatars 默认可能返回 SVG，Flutter 无法解码，强制 `format=png`；失败时显示首字。
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final UserModel user;

  static String _initial(String username) {
    if (username.isEmpty) return '?';
    return String.fromCharCode(username.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final url = resolveAvatarUrl(user.avatarUrl, user.username);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        httpHeaders: kRemoteImageHttpHeaders,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 84,
          height: 84,
          color: Colors.white24,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => CircleAvatar(
          radius: 42,
          backgroundColor: Colors.white24,
          child: Text(
            _initial(user.username),
            style: const TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
