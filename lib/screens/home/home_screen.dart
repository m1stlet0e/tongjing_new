// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`home_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/theme/app_colors.dart';

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
  static const _mockImage =
      'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1200&q=80';

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

  @override
  /// 组件初始化阶段执行一次，用于准备首屏数据与监听器。
  ///
  /// 方法：`initState`。
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
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

  Future<void> _loadPage({bool refresh = false}) async {
    if (AppConfig.useMockData) {
      setState(() {
        _photos
          ..clear()
          ..addAll(_mockPhotos());
        _loading = false;
        _loadingMore = false;
        _hasMore = false;
        _error = null;
      });
      return;
    }

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
      setState(() {
        if (refresh) {
          _photos
            ..clear()
            ..addAll(r.photos);
          _page = 2;
        } else {
          _photos.addAll(r.photos);
          _page = page + 1;
        }
        _hasMore = r.photos.length >= _feedPageLimit;
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

  Future<void> _afterReturnFromDetail(int photoId) async {
    if (AppConfig.useMockData || !mounted) return;
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) return;
    try {
      final d = await auth.api.photoDetail(photoId);
      if (!mounted) return;
      _replacePhotoInList(photoId, d);
      final snap = _photosByTab[_uiTab];
      if (snap != null) {
        final i = snap.indexWhere((x) => x.id == photoId);
        if (i >= 0) {
          snap[i] = d;
        }
      }
    } catch (_) {}
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        '同镜',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
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
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
              fontWeight: on ? FontWeight.w600 : FontWeight.normal,
              color: on ? AppColors.kleinBlue : AppColors.textMuted,
            ),
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
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
                    interactionsEnabled: !AppConfig.useMockData,
                    onOpenDetail: () async {
                      await context.push('/photo/${p.id}');
                      if (mounted) await _afterReturnFromDetail(p.id);
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
    if (AppConfig.useMockData) return;
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
    } on ApiException catch (e) {
      _replacePhotoInList(photoId, before);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      _likeBusy.remove(photoId);
    }
  }

  Future<void> _toggleFavoriteOnTile(int photoId) async {
    if (AppConfig.useMockData) return;
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
    } on ApiException catch (e) {
      _replacePhotoInList(photoId, before);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      _favoriteBusy.remove(photoId);
    }
  }

  List<PhotoListItem> _mockPhotos() {
    final tabTitle = switch (_uiTab) {
      'latest' => '最新',
      'following' => '关注',
      _ => '推荐',
    };
    final base = [
      PhotoListItem(
        id: 90001,
        imageUrl: _mockImage,
        title: '$tabTitle · 外滩蓝调时刻',
        locationName: '上海外滩观景台',
        cameraModel: 'Sony A7M4',
        focalLength: '50mm',
        aperture: '1.8',
        shutterSpeed: '1/125',
        iso: 320,
        likesCount: 128,
        latitude: 31.2400,
        longitude: 121.4900,
      ),
      PhotoListItem(
        id: 90002,
        imageUrl:
            'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 城市夜景长曝光',
        locationName: '陆家嘴滨江',
        cameraModel: 'Canon R6',
        focalLength: '24-70mm',
        aperture: '8',
        shutterSpeed: '4s',
        iso: 100,
        likesCount: 96,
        latitude: 31.2350,
        longitude: 121.5070,
      ),
      PhotoListItem(
        id: 90003,
        imageUrl:
            'https://images.unsplash.com/photo-1482192596544-9eb780fc7f66?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 武康大楼街拍',
        locationName: '武康路',
        cameraModel: 'Fujifilm X-T5',
        focalLength: '35mm',
        aperture: '2.0',
        shutterSpeed: '1/250',
        iso: 200,
        likesCount: 73,
        latitude: 31.2044,
        longitude: 121.4338,
      ),
      PhotoListItem(
        id: 90004,
        imageUrl:
            'https://images.unsplash.com/photo-1446776877081-d282a0f896e2?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 星轨练习',
        locationName: '崇明郊外',
        cameraModel: 'Nikon Z6',
        focalLength: '20mm',
        aperture: '2.8',
        shutterSpeed: '20s',
        iso: 1600,
        likesCount: 54,
        latitude: 31.6230,
        longitude: 121.3970,
      ),
      PhotoListItem(
        id: 90005,
        imageUrl:
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 雪山日出',
        locationName: '川西垭口',
        cameraModel: 'Sony A7R5',
        focalLength: '70-200mm',
        aperture: '5.6',
        shutterSpeed: '1/500',
        iso: 400,
        likesCount: 210,
        username: '山行客',
        latitude: 30.8,
        longitude: 102.0,
      ),
      PhotoListItem(
        id: 90006,
        imageUrl:
            'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 极简雪山',
        locationName: '阿尔卑斯风格参考',
        cameraModel: 'Leica Q3',
        focalLength: '28mm',
        aperture: '2.8',
        shutterSpeed: '1/2000',
        iso: 100,
        likesCount: 178,
        username: '极简派',
      ),
      PhotoListItem(
        id: 90007,
        imageUrl:
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 森林晨雾',
        locationName: '天目山古道',
        cameraModel: 'Canon R5',
        focalLength: '85mm',
        aperture: '1.4',
        shutterSpeed: '1/160',
        iso: 640,
        likesCount: 92,
        username: '雾行者',
      ),
      PhotoListItem(
        id: 90008,
        imageUrl:
            'https://images.unsplash.com/photo-1493246507139-91e8fad9978e?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 湖畔倒影',
        locationName: '千岛湖',
        cameraModel: 'Nikon Z8',
        focalLength: '24mm',
        aperture: '11',
        shutterSpeed: '1/60',
        iso: 100,
        likesCount: 145,
        username: '静水',
      ),
      PhotoListItem(
        id: 90009,
        imageUrl:
            'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 公路尽头',
        locationName: '青海公路',
        cameraModel: 'Fujifilm GFX',
        focalLength: '45mm',
        aperture: '8',
        shutterSpeed: '1/250',
        iso: 200,
        likesCount: 167,
        username: 'RoadTrip',
      ),
      PhotoListItem(
        id: 90010,
        imageUrl:
            'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 云海层峦',
        locationName: '黄山',
        cameraModel: 'Sony A7M4',
        focalLength: '70mm',
        aperture: '4',
        shutterSpeed: '1/320',
        iso: 250,
        likesCount: 301,
        username: '云上',
      ),
      PhotoListItem(
        id: 90011,
        imageUrl:
            'https://images.unsplash.com/photo-1518837695005-2083093ee35b?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 赛博霓虹',
        locationName: '涩谷风格参考',
        cameraModel: 'Sony A7C',
        focalLength: '35mm',
        aperture: '1.8',
        shutterSpeed: '1/80',
        iso: 800,
        likesCount: 412,
        username: 'NeonLab',
      ),
      PhotoListItem(
        id: 90012,
        imageUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=1200&q=80',
        title: '$tabTitle · 人像自然光',
        locationName: '工作室窗光',
        cameraModel: 'Canon R6',
        focalLength: '50mm',
        aperture: '1.4',
        shutterSpeed: '1/200',
        iso: 200,
        likesCount: 88,
        username: '肖像师',
      ),
    ];
    List<PhotoListItem> expanded = base;
    if (_uiTab == 'latest' || _uiTab == 'following') {
      expanded = [...base];
      for (var round = 1; round < 5; round++) {
        for (final p in base) {
          expanded.add(
            p.copyWith(
              id: p.id + round * 10000,
              title: '${p.title ?? '作品'} · 续$round',
            ),
          );
        }
      }
    }
    return expanded
        .map(
          (p) => p.copyWith(
            userId: 88001 + (p.id % 3),
            username: p.username ?? '演示作者${(p.id % 3) + 1}',
          ),
        )
        .toList();
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
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onOpenDetail(),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFFEEEEEE)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => onOpenDetail(),
                  child: Text(
                    item.title ?? '未命名',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
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
                                style: const TextStyle(
                                  fontSize: 11,
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  const SizedBox(height: 2),
                  Text(
                    _cameraLine(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: interactionsEnabled ? onToggleLike : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: item.isLiked
                                  ? Colors.red
                                  : AppColors.textMuted,
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
                      const SizedBox(width: 10),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: interactionsEnabled ? onToggleFavorite : null,
                        child: Icon(
                          item.isFavorited ? Icons.star : Icons.star_border,
                          size: 14,
                          color: item.isFavorited
                              ? AppColors.champagneGold
                              : AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _distanceTag(item),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
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
