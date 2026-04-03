// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`home_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/services/photo_state_sync_bus.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/theme/app_spacing.dart';
import 'package:tongjing/theme/app_typography.dart';
import 'package:tongjing/theme/app_shapes.dart';
import 'package:tongjing/utils/remote_image.dart';
import 'package:tongjing/utils/top_notice.dart';

/// `HomeScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// `_HomeScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _HomeScreenState extends State<HomeScreen> {
  final List<PhotoListItem> _photos = [];
  final _search = TextEditingController();
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _uiTab = 'recommend';

  String? _brandFilter;
  String? _lensFilter;
  String? _sceneFilter;
  /// `null` 全部；`low` ≤400；`mid` 401–3200；`high` &gt;3200（与后端 `iso_min`/`iso_max` 对应）。
  String? _isoFilter;

  static const _brands = ['Sony', 'Canon', 'Nikon', '富士', 'Leica'];
  static const _lens = ['35mm', '50mm', '85mm', '24-70', '70-200'];
  static const _scenes = ['人像', '风光', '街拍', '建筑', '星空', '夜景'];
  static const _isoLabels = <String, String>{
    'low': '低感光 (≤400)',
    'mid': '中感光 (401–3200)',
    'high': '高感光 (>3200)',
  };

  /// 首页单次拉取条数（真实接口与分页判断一致）
  static const int _feedPageLimit = 32;

  /// 避免快速切换 Tab 时旧请求覆盖新列表。
  int _feedReqId = 0;

  /// 各 Tab 上次成功加载的快照，用于切换时先展示再后台刷新。
  final Map<String, List<PhotoListItem>> _photosByTab = {};
  final Map<String, int> _pageByTab = {};
  final Map<String, bool> _hasMoreByTab = {};

  final Set<int> _likeBusy = {};
  final Set<int> _favoriteBusy = {};
  final PhotoStateSyncBus _syncBus = PhotoStateSyncBus.instance;

  @override
  /// 组件初始化阶段执行一次，用于准备首屏数据与监听器。
  ///
  /// 方法：`initState`。
  void initState() {
    super.initState();
    _refresh();
    _syncBus.addListener(_onPhotoStateSync);
  }

  @override
  void dispose() {
    _syncBus.removeListener(_onPhotoStateSync);
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _photosByTab.clear();
      _pageByTab.clear();
      _hasMoreByTab.clear();
    });
    await _loadPage(refresh: true);
  }

  void _onPhotoStateSync() {
    final e = _syncBus.lastEvent;
    if (!mounted || e == null) return;
    final idx = _photos.indexWhere((x) => x.id == e.photoId);
    if (idx < 0) return;
    final before = _photos[idx];
      final next = before.copyWith(
        isLiked: e.isLiked ?? before.isLiked,
        likesCount: e.likesCount ?? before.likesCount,
        isFavorited: e.isFavorited ?? before.isFavorited,
        favoritesCount: e.favoritesCount ?? before.favoritesCount,
      );
      _replacePhotoInList(e.photoId, next);
  }

  Future<void> _loadPage({bool refresh = false}) async {
    final auth = context.read<AuthNotifier>();
    if (_loadingMore && !refresh) return;
    if (!_hasMore && !refresh) return;

    final req = ++_feedReqId;
    if (!refresh) setState(() => _loadingMore = true);

    try {
      final page = refresh ? 1 : _page;
      final isoRange = _isoQueryRange();
      final r = await auth.api.photosFeed(
        page: page,
        limit: _feedPageLimit,
        uiTab: _uiTab,
        camera: _brandFilter,
        lens: _lensFilter,
        scene: _sceneFilter,
        isoMin: isoRange.$1,
        isoMax: isoRange.$2,
      );
      if (!mounted || req != _feedReqId) return;
      final synced = r.photos.map(_syncBus.patchPhoto).toList();
      setState(() {
        if (refresh) {
          _photos
            ..clear()
            ..addAll(synced);
          _page = 2;
        } else {
          _photos.addAll(synced);
          _page = page + 1;
        }
        _hasMore = synced.length >= _feedPageLimit;
        _error = null;
      });
      final keyword = _search.text.trim().toLowerCase();
      if (keyword.isNotEmpty && mounted && req == _feedReqId) {
        setState(() {
          _photos.retainWhere(
            (p) =>
                (p.title ?? '').toLowerCase().contains(keyword) ||
                (p.locationName ?? '').toLowerCase().contains(keyword) ||
                (p.cameraModel ?? '').toLowerCase().contains(keyword),
          );
        });
      }
      if (mounted && req == _feedReqId) {
        _photosByTab[_uiTab] = List<PhotoListItem>.from(_photos);
        _pageByTab[_uiTab] = _page;
        _hasMoreByTab[_uiTab] = _hasMore;
      }
    } catch (e) {
      if (!mounted || req != _feedReqId) return;
      setState(() {
        _error = e is ApiException ? e.message : '加载失败：$e';
      });
    } finally {
      if (mounted && req == _feedReqId) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _switchUiTab(String key) {
    if (_uiTab == key) return;
    final cached = _photosByTab[key];
    setState(() {
      _uiTab = key;
      if (cached != null) {
        _photos
          ..clear()
          ..addAll(cached);
        _page = _pageByTab[key] ?? 2;
        _hasMore = _hasMoreByTab[key] ?? true;
        _loading = false;
        _loadingMore = false;
        _error = null;
      } else {
        _loading = true;
        _photos.clear();
        _page = 1;
        _hasMore = true;
        _error = null;
      }
    });
    unawaited(_loadPage(refresh: true));
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_openFilter`。
  void _openFilter() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String? b = _brandFilter;
        String? l = _lensFilter;
        String? s = _sceneFilter;
        String? iso = _isoFilter;
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewPadding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('相机品牌',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: b == null,
                        onSelected: (_) => setModal(() => b = null),
                      ),
                      ..._brands.map(
                        (e) => ChoiceChip(
                          label: Text(e),
                          selected: b == e,
                          onSelected: (_) => setModal(() => b = e),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('镜头关键词',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: l == null,
                        onSelected: (_) => setModal(() => l = null),
                      ),
                      ..._lens.map(
                        (e) => ChoiceChip(
                          label: Text(e),
                          selected: l == e,
                          onSelected: (_) => setModal(() => l = e),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('题材',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: s == null,
                        onSelected: (_) => setModal(() => s = null),
                      ),
                      ..._scenes.map(
                        (e) => ChoiceChip(
                          label: Text(e),
                          selected: s == e,
                          onSelected: (_) => setModal(() => s = e),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('ISO 感光度',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: iso == null,
                        onSelected: (_) => setModal(() => iso = null),
                      ),
                      ..._isoLabels.entries.map(
                        (e) => ChoiceChip(
                          label: Text(e.value),
                          selected: iso == e.key,
                          onSelected: (_) => setModal(() => iso = e.key),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _brandFilter = b;
                          _lensFilter = l;
                          _sceneFilter = s;
                          _isoFilter = iso;
                        });
                        Navigator.pop(ctx);
                        _refresh();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.kleinBlue,
                      ),
                      child: const Text('应用'),
                    ),
                  ),
                ],
              ),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.sm,
                AppSpacing.xxl,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '同镜',
                        style: AppTypography.pageTitle.copyWith(
                          color: AppColors.kleinBlue,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _openFilter,
                        icon: const Icon(
                          Icons.tune,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _search,
                    onSubmitted: (_) => _refresh(),
                    decoration: InputDecoration(
                      hintText: '搜索作品/机位/标签',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: AppShapes.radiusXlAll,
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppShapes.radiusXlAll,
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _tabChip('推荐', 'recommend'),
                _tabChip('最新', 'latest'),
                _tabChip('关注', 'following'),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.kleinBlue,
                onRefresh: _refresh,
                child: _buildBody(isLoggedIn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_tabChip`。
  Widget _tabChip(String label, String key) {
    final on = _uiTab == key;
    return Expanded(
      child: InkWell(
        onTap: () => _switchUiTab(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
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
            style: on ? AppTypography.tabSelected : AppTypography.tabUnselected,
          ),
        ),
      ),
    );
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_buildBody`。
  Widget _buildBody(bool isLoggedIn) {
    final shown = _photos;
    if (_loading && _photos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _photos.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          TextButton(onPressed: _refresh, child: const Text('重试')),
        ],
      );
    }
    if (shown.isEmpty) {
      if (_photos.isNotEmpty) {
        return ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('暂无符合筛选的作品')),
          ],
        );
      }
      if (_uiTab == 'following') {
        return ListView(
          children: [
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                isLoggedIn
                    ? '关注页暂无动态。你可先去「推荐」浏览作品，在作者主页点击「+ 关注」；演示环境需种子数据中为演示账号写入关注关系。'
                    : '登录后可查看已关注摄影师的最新作品。',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: FilledButton(
                onPressed: () {
                  if (isLoggedIn) {
                    _refresh();
                  } else {
                    context.push('/login');
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.kleinBlue),
                child: Text(isLoggedIn ? '刷新试试' : '去登录'),
              ),
            ),
          ],
        );
      }
      return ListView(
        children: [
          const SizedBox(height: 120),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Text(
                '暂无作品。数据库为空时重启后端会自动写入演示数据；也可登录后在「发布」上传。',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          TextButton(onPressed: _refresh, child: const Text('刷新')),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
          _loadPage();
        }
        return false;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.huge,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.lg,
                crossAxisSpacing: AppSpacing.lg,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= shown.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final p = shown[index];
                  return RepaintBoundary(
                    child: _PhotoTile(
                    item: p,
                    interactionsEnabled: true,
                    onOpenDetail: () async {
                      final r = await context.push('/photo/${p.id}');
                      if (!mounted) return;
                      if (r == true) {
                        await _refresh();
                      }
                    },
                    onOpenAuthor: (p.userId != null && p.userId! > 0)
                        ? () => context.push('/user/${p.userId}')
                        : null,
                    onToggleLike: () => _toggleLikeOnTile(p.id),
                    onToggleFavorite: () => _toggleFavoriteOnTile(p.id),
                  ),
                  );
                },
                childCount: shown.length + (_loadingMore ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 与筛选 chips 对应的后端 `iso_min` / `iso_max`；无筛选时为 (null, null)。
  (int?, int?) _isoQueryRange() {
    switch (_isoFilter) {
      case 'low':
        return (null, 400);
      case 'mid':
        return (401, 3200);
      case 'high':
        return (3201, null);
      default:
        return (null, null);
    }
  }

  void _replacePhotoInList(int photoId, PhotoListItem next) {
    final idx = _photos.indexWhere((x) => x.id == photoId);
    if (idx < 0 || !mounted) return;
    setState(() => _photos[idx] = next);
    final cached = _photosByTab[_uiTab];
    if (cached != null) {
      final j = cached.indexWhere((x) => x.id == photoId);
      if (j >= 0) cached[j] = next;
    }
  }

  Future<void> _toggleLikeOnTile(int photoId) async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      if (mounted) context.push('/login');
      return;
    }
    if (_likeBusy.contains(photoId)) return;
    final idx = _photos.indexWhere((x) => x.id == photoId);
    if (idx < 0) return;
    final before = _photos[idx];
    final optimistic = before.copyWith(
      isLiked: !before.isLiked,
      likesCount:
          (before.likesCount + (before.isLiked ? -1 : 1)).clamp(0, 1 << 30),
    );
    _likeBusy.add(photoId);
    _replacePhotoInList(photoId, optimistic);
    HapticFeedback.selectionClick();
    try {
      final liked = await auth.api.photoToggleLike(photoId);
      if (!mounted) return;
      var count = before.likesCount;
      if (liked && !before.isLiked) count++;
      if (!liked && before.isLiked) count--;
      _replacePhotoInList(
        photoId,
        before.copyWith(
          isLiked: liked,
          likesCount: count.clamp(0, 1 << 30),
        ),
      );
      _syncBus.emit(
        PhotoStateSyncEvent(
          photoId: photoId,
          isLiked: liked,
          likesCount: count.clamp(0, 1 << 30),
          photo: before.copyWith(
            isLiked: liked,
            likesCount: count.clamp(0, 1 << 30),
          ),
        ),
      );
    } on ApiException catch (e) {
      _replacePhotoInList(photoId, before);
      if (mounted) {
        showTopNotice(context, e.message, error: true);
      }
    } finally {
      _likeBusy.remove(photoId);
    }
  }

  Future<void> _toggleFavoriteOnTile(int photoId) async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      if (mounted) context.push('/login');
      return;
    }
    if (_favoriteBusy.contains(photoId)) return;
    final idx = _photos.indexWhere((x) => x.id == photoId);
    if (idx < 0) return;
    final before = _photos[idx];
    final optimistic = before.copyWith(
      isFavorited: !before.isFavorited,
      favoritesCount: (before.favoritesCount + (before.isFavorited ? -1 : 1))
          .clamp(0, 1 << 30),
    );
    _favoriteBusy.add(photoId);
    _replacePhotoInList(photoId, optimistic);
    HapticFeedback.selectionClick();
    try {
      final fav = await auth.api.photoToggleFavorite(photoId);
      if (!mounted) return;
      var count = before.favoritesCount;
      if (fav && !before.isFavorited) count++;
      if (!fav && before.isFavorited) count--;
      _replacePhotoInList(
        photoId,
        before.copyWith(
          isFavorited: fav,
          favoritesCount: count.clamp(0, 1 << 30),
        ),
      );
      _syncBus.emit(
        PhotoStateSyncEvent(
          photoId: photoId,
          isFavorited: fav,
          favoritesCount: count.clamp(0, 1 << 30),
          photo: before.copyWith(
            isFavorited: fav,
            favoritesCount: count.clamp(0, 1 << 30),
          ),
        ),
      );
    } on ApiException catch (e) {
      _replacePhotoInList(photoId, before);
      if (mounted) {
        showTopNotice(context, e.message, error: true);
      }
    } finally {
      _favoriteBusy.remove(photoId);
    }
  }

}

/// `_PhotoTile`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.item,
    required this.onOpenDetail,
    this.onOpenAuthor,
    required this.onToggleLike,
    required this.onToggleFavorite,
    required this.interactionsEnabled,
  });

  final PhotoListItem item;
  final Future<void> Function() onOpenDetail;
  final VoidCallback? onOpenAuthor;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleFavorite;
  final bool interactionsEnabled;

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppShapes.radiusXlAll,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onOpenDetail(),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                httpHeaders: kRemoteImageHttpHeaders,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: AppColors.placeholder),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => onOpenDetail(),
                  child: Text(
                    item.title ?? '未命名',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AppSpacing.verticalXs,
                onOpenAuthor != null
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onOpenAuthor,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.username == null || item.username!.isEmpty
                                    ? '@匿名作者'
                                    : '@${item.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.kleinBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 14, color: AppColors.kleinBlue),
                          ],
                        ),
                      )
                    : Text(
                        item.username == null || item.username!.isEmpty
                            ? '@匿名作者'
                            : '@${item.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall,
                      ),
                AppSpacing.verticalXs,
                Text(
                  _cameraLine(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.paramInfo,
                ),
                AppSpacing.verticalXs,
                  Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: null,
                        child: InkResponse(
                          onTap: interactionsEnabled ? onToggleLike : null,
                          radius: 18,
                          containedInkWell: false,
                          child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 90),
                              curve: Curves.easeOutBack,
                              tween: Tween<double>(
                                begin: 1,
                                end: item.isLiked ? 1.14 : 1.0,
                              ),
                              builder: (context, scale, child) {
                                return Transform.scale(scale: scale, child: child);
                              },
                              child: Icon(
                                item.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 14,
                                color: item.isLiked
                                    ? Colors.red
                                    : AppColors.textMuted,
                              ),
                            ),
                            Text(
                              ' ${item.likesCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: item.isLiked
                                    ? Colors.red
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                      AppSpacing.horizontalLg,
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: null,
                        child: InkResponse(
                          onTap: interactionsEnabled ? onToggleFavorite : null,
                          radius: 18,
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 90),
                            curve: Curves.easeOutBack,
                            tween: Tween<double>(
                              begin: 1,
                              end: item.isFavorited ? 1.14 : 1.0,
                            ),
                            builder: (context, scale, child) {
                              return Transform.scale(scale: scale, child: child);
                            },
                            child: Icon(
                              item.isFavorited ? Icons.star : Icons.star_border,
                              size: 14,
                              color: item.isFavorited
                                  ? AppColors.favorite
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _distanceTag(item),
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _cameraLine(PhotoListItem p) {
    final parts = <String>[];
    if (p.cameraModel != null && p.cameraModel!.isNotEmpty) {
      parts.add(p.cameraModel!);
    }
    if (p.focalLength != null && p.focalLength!.isNotEmpty) {
      parts.add(p.focalLength!);
    }
    if (p.aperture != null && p.aperture!.isNotEmpty) {
      parts.add('f/${p.aperture}');
    }
    return parts.isEmpty ? '参数待补充' : parts.join(' | ');
  }

  String _distanceTag(PhotoListItem p) => '距你 ${(p.id % 35) + 1}km';

}
