// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`home_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/providers/auth_provider.dart';
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
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _uiTab = 'recommend';

  String? _brandFilter;
  String? _sceneFilter;

  static const _brands = ['Sony', 'Canon', 'Nikon', '富士', 'Leica'];
  static const _scenes = ['人像', '风光', '街拍', '建筑', '星空', '夜景'];

  @override
  /// 组件初始化阶段执行一次，用于准备首屏数据与监听器。
  ///
  /// 方法：`initState`。
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    await _loadPage(refresh: true);
  }

  Future<void> _loadPage({bool refresh = false}) async {
    final auth = context.read<AuthNotifier>();
    if (_loadingMore && !refresh) return;
    if (!_hasMore && !refresh) return;

    if (!refresh) setState(() => _loadingMore = true);

    try {
      final page = refresh ? 1 : _page;
      final r = await auth.api.photosFeed(
        page: page,
        limit: 20,
        uiTab: _uiTab,
        camera: _brandFilter,
        scene: _sceneFilter,
      );
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
        _hasMore = r.photos.length >= 20;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
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
        String? s = _sceneFilter;
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _brandFilter = b;
                          _sceneFilter = s;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
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
                    icon: const Icon(Icons.tune, color: AppColors.textSecondary),
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
                child: _buildBody(),
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
        onTap: () {
          if (_uiTab == key) return;
          setState(() => _uiTab = key);
          _refresh();
        },
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
  Widget _buildBody() {
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
    if (_photos.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('暂无作品')),
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
                  if (index >= _photos.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final p = _photos[index];
                  return _PhotoTile(
                    item: p,
                    onTap: () => context.push('/photo/${p.id}'),
                  );
                },
                childCount: _photos.length + (_loadingMore ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `_PhotoTile`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.item, required this.onTap});

  final PhotoListItem item;
  final VoidCallback onTap;

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFFEEEEEE)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title ?? '未命名',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
                      Icon(Icons.favorite_border,
                          size: 14, color: AppColors.textMuted),
                      Text(' ${item.likesCount}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
}
