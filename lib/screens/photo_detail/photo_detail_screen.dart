// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`photo_detail_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/screens/map/map_screen.dart' show MapOpenArgs;
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/models/plan_item.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/router/app_router.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/services/plan_store.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/utils/remote_image.dart';

/// 作品详情：黑底 + [BoxFit.contain] 完整显示照片（不裁切），底部可拖拽信息抽屉。
///
/// 从网格带 [PhotoGalleryExtra] 进入时，可左右滑动浏览同一批作品。
class PhotoDetailScreen extends StatelessWidget {
  const PhotoDetailScreen({
    super.key,
    required this.photoId,
    this.galleryPhotoIds,
    this.galleryInitialIndex = 0,
  });

  final int photoId;
  final List<int>? galleryPhotoIds;
  final int galleryInitialIndex;

  @override
  Widget build(BuildContext context) {
    final ids = galleryPhotoIds;
    if (ids != null && ids.length > 1) {
      var ix = galleryInitialIndex.clamp(0, ids.length - 1);
      if (ids[ix] != photoId) {
        final f = ids.indexOf(photoId);
        if (f >= 0) ix = f;
      }
      return _PhotoGalleryPager(photoIds: ids, initialIndex: ix);
    }
    return _PhotoDetailPage(
      key: ValueKey(photoId),
      photoId: photoId,
      onPhotoDeletedFromGallery: null,
    );
  }
}

class _PhotoGalleryPager extends StatefulWidget {
  const _PhotoGalleryPager({
    required this.photoIds,
    required this.initialIndex,
  });

  final List<int> photoIds;
  final int initialIndex;

  @override
  State<_PhotoGalleryPager> createState() => _PhotoGalleryPagerState();
}

class _PhotoGalleryPagerState extends State<_PhotoGalleryPager> {
  late List<int> _ids;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _ids = List<int>.from(widget.photoIds);
    final ix = widget.initialIndex.clamp(0, _ids.length - 1);
    _controller = PageController(initialPage: ix);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPhotoDeletedFromGallery(int deletedId) {
    final cur = (_controller.page ?? _controller.initialPage.toDouble()).round();
    final idx = _ids.indexOf(deletedId);
    if (idx < 0) return;
    setState(() => _ids.removeAt(idx));
    if (_ids.isEmpty) {
      if (mounted) context.pop(true);
      return;
    }
    var newPage = cur;
    if (idx < cur) {
      newPage = cur - 1;
    } else if (idx == cur && cur >= _ids.length) {
      newPage = _ids.length - 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.jumpToPage(newPage.clamp(0, _ids.length - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: _ids.length,
      itemBuilder: (context, i) {
        return _PhotoDetailPage(
          key: ValueKey(_ids[i]),
          photoId: _ids[i],
          onPhotoDeletedFromGallery: _onPhotoDeletedFromGallery,
        );
      },
    );
  }
}

class _PhotoDetailPage extends StatefulWidget {
  const _PhotoDetailPage({
    super.key,
    required this.photoId,
    required this.onPhotoDeletedFromGallery,
  });

  final int photoId;

  /// 非空时表示处于作品画廊内，删除后由外层更新列表而非整页 pop。
  final void Function(int photoId)? onPhotoDeletedFromGallery;

  @override
  State<_PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends State<_PhotoDetailPage>
    with AutomaticKeepAliveClientMixin {
  final _planStore = PlanStore();
  final TransformationController _imageTransform = TransformationController();
  PhotoDetail? _photo;
  bool _loading = true;
  String? _error;
  bool _inPlan = false;

  /// 与底部抽屉初始高度比例大致对齐，照片在「可见区」内居中（类相册应用习惯）。
  static const double _imageBottomReserveFraction = 0.11;

  /// 抽屉高度：默认更低，留出更多看图区域。
  static const double _sheetInitial = 0.11;
  static const double _sheetMin = 0.08;
  static const double _sheetMax = 0.76;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _imageTransform.dispose();
    super.dispose();
  }

  /// 未放大时不允许拖动照片（避免与相册左右滑抢手势、也避免 1 倍下乱移画面）。
  void _snapImageTransformIfNotZoomed() {
    final s = _imageTransform.value.getMaxScaleOnAxis();
    if (s <= 1.001) {
      _imageTransform.value = Matrix4.identity();
    }
  }

  Future<void> _fetch() async {
    if (widget.photoId <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthNotifier>().api;
      final p = await api.photoDetail(widget.photoId);
      setState(() => _photo = p);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await _syncPlanFlag();
  }

  void _pushMyPlansUsingRootNavigator() {
    final root = rootNavigatorKey.currentContext;
    if (root == null || !root.mounted) return;
    GoRouter.of(root).push('/my-plans');
  }

  void _openLocationOnMap() {
    final p = _photo;
    if (p == null) return;
    final name = p.locationName?.trim();
    if (name == null || name.isEmpty) return;
    final lat = p.latitude;
    final lng = p.longitude;
    if (lat != null && lng != null) {
      context.go(
        '/map',
        extra: MapOpenArgs(lat: lat, lng: lng, hintName: name),
      );
    } else {
      context.go('/map');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该作品未标注坐标，已打开地图，可在列表中浏览附近作品')),
        );
      });
    }
  }

  Future<void> _syncPlanFlag() async {
    final p = _photo;
    if (p == null) return;
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      if (mounted) setState(() => _inPlan = false);
      return;
    }
    try {
      final has = await _planStore.containsPhoto(auth.api, p.id);
      if (mounted) setState(() => _inPlan = has);
    } catch (_) {
      if (mounted) setState(() => _inPlan = false);
    }
  }

  Future<void> _addToPlan() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      if (mounted) context.push('/login');
      return;
    }
    final p = _photo;
    if (p == null) return;
    try {
      await _planStore.upsert(
        auth.api,
        PlanItem(
          photoId: p.id,
          title: p.title ?? '未命名拍摄计划',
          location: p.locationName ?? '未标记机位',
          imageUrl: p.imageUrl,
          cameraLine:
              '${p.cameraModel ?? '-'} | ${p.focalLength ?? '-'} | f/${p.aperture ?? '-'}',
          tips: p.shootingTips,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加入失败：$e')));
      return;
    }
    if (!mounted) return;
    setState(() => _inPlan = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已加入拍摄计划'),
        action: SnackBarAction(
          label: '查看',
          onPressed: _pushMyPlansUsingRootNavigator,
        ),
      ),
    );
  }

  Future<void> _like() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    try {
      final liked = await auth.api.photoToggleLike(widget.photoId);
      setState(() {
        if (_photo != null) {
          final prev = _photo!;
          final delta = liked == prev.isLiked ? 0 : (liked ? 1 : -1);
          _photo = prev.copyWith(
            isLiked: liked,
            likesCount: (prev.likesCount + delta).clamp(0, 1 << 30),
          );
        }
      });
      if (mounted) await context.read<AuthNotifier>().refreshProfile();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _favorite() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    try {
      final fav = await auth.api.photoToggleFavorite(widget.photoId);
      if (!mounted || _photo == null) return;
      final prev = _photo!;
      final delta = fav == prev.isFavorited ? 0 : (fav ? 1 : -1);
      setState(() {
        _photo = prev.copyWith(
          isFavorited: fav,
          favoritesCount: (prev.favoritesCount + delta).clamp(0, 1 << 30),
        );
      });
      await _syncPlanFlag();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fav ? '已加入收藏' : '已取消收藏')),
      );
      if (mounted) await context.read<AuthNotifier>().refreshProfile();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除作品'),
        content: const Text('确定删除这张照片？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final api = context.read<AuthNotifier>().api;
    try {
      await api.photoDelete(widget.photoId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
    await context.read<AuthNotifier>().refreshProfile();
    if (!mounted) return;
    final galleryCb = widget.onPhotoDeletedFromGallery;
    if (galleryCb != null) {
      galleryCb(widget.photoId);
    } else {
      if (mounted) context.pop(true);
    }
  }

  Widget _buildAuthorRow(BuildContext context) {
    final p = _photo!;
    final name = p.username ?? '匿名作者';
    final uid = p.userId;
    if (uid == null || uid <= 0) {
      return Text(
        '作者：$name',
        style: const TextStyle(color: AppColors.textSecondary),
      );
    }
    return InkWell(
      onTap: () => context.push('/user/$uid'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE8ECF5),
              child: Text(
                name.isNotEmpty
                    ? String.fromCharCode(name.runes.first)
                    : '?',
                style: const TextStyle(
                  color: AppColors.kleinBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    '查看主页',
                    style: TextStyle(fontSize: 12, color: AppColors.kleinBlue),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  /// 完整显示图片（contain），不裁切；不按视口缩小解码，避免额外「压缩感」（超大图仍受设备内存限制）。
  Widget _buildPhotoViewport(BuildContext context) {
    final url = _photo!.imageUrl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) {
          return const SizedBox.expand();
        }
        return InteractiveViewer(
          transformationController: _imageTransform,
          onInteractionUpdate: (_) => _snapImageTransformIfNotZoomed(),
          onInteractionEnd: (_) => _snapImageTransformIfNotZoomed(),
          panAxis: PanAxis.free,
          minScale: 1,
          maxScale: 5,
          clipBehavior: Clip.hardEdge,
          boundaryMargin: const EdgeInsets.all(80),
          child: SizedBox(
            width: w,
            height: h,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                httpHeaders: kRemoteImageHttpHeaders,
                fit: BoxFit.contain,
                width: w,
                height: h,
                fadeInDuration: const Duration(milliseconds: 180),
                fadeInCurve: Curves.easeOut,
                filterQuality: FilterQuality.high,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white38,
                    strokeWidth: 2,
                  ),
                ),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 点赞 / 收藏 / 计划 一行，与下方文案区分离。
  Widget _buildActionBar({required bool isMine}) {
    final p = _photo!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _like,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Icon(
                        p.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: p.isLiked ? Colors.redAccent : AppColors.textSecondary,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.likesCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isMine ? '获赞' : '点赞',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 44, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _favorite,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Icon(
                        p.isFavorited ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: p.isFavorited ? AppColors.champagneGold : AppColors.textSecondary,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.favoritesCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isMine ? '被收藏' : '收藏',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 44, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: _inPlan
                  ? OutlinedButton.icon(
                      onPressed: () => context.push('/my-plans'),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('已在计划'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kleinBlue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _addToPlan,
                      icon: const Icon(Icons.add_task, size: 18),
                      label: const Text('拍计划'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.kleinBlue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final meId = context.select<AuthNotifier, int?>(
        (a) => a.isAuthenticated ? a.user?.id : null);
    final topPad = MediaQuery.paddingOf(context).top;
    final screenH = MediaQuery.sizeOf(context).height;
    final imageBottomPad = screenH * _imageBottomReserveFraction;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
              : _photo == null
                  ? const SizedBox.shrink()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: imageBottomPad),
                            child: _buildPhotoViewport(context),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: topPad + 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.black.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: topPad + 4,
                          left: 4,
                          right: 4,
                          child: Row(
                            children: [
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0x66000000),
                                ),
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => context.pop(),
                              ),
                              const Spacer(),
                              if (meId != null && meId == _photo!.userId)
                                IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0x66000000),
                                  ),
                                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                                  onPressed: _delete,
                                ),
                            ],
                          ),
                        ),
                        DraggableScrollableSheet(
                          initialChildSize: _sheetInitial,
                          minChildSize: _sheetMin,
                          maxChildSize: _sheetMax,
                          snap: true,
                          snapSizes: const [_sheetMin, _sheetInitial, 0.42, _sheetMax],
                          builder: (context, controller) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 24,
                                    offset: const Offset(0, -6),
                                  ),
                                ],
                              ),
                              child: ListView(
                                controller: controller,
                                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                                children: [
                                  Center(
                                    child: Container(
                                      width: 36,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC9CED6),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildActionBar(
                                    isMine: meId != null && _photo!.userId != null && meId == _photo!.userId,
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    _photo!.title ?? '未命名',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildAuthorRow(context),
                                  if (_photo!.description != null &&
                                      _photo!.description!.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      _photo!.description!,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.55,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.tune, size: 18, color: AppColors.kleinBlue),
                                            const SizedBox(width: 6),
                                            const Text(
                                              '拍摄参数',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '${_photo!.cameraBrand ?? ''} ${_photo!.cameraModel ?? ''}'.trim(),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_photo!.focalLength ?? '-'}  |  f/${_photo!.aperture ?? '-'}  |  ${_photo!.shutterSpeed ?? '-'}  |  ISO ${_photo!.iso ?? '-'}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        if (_photo!.locationName != null &&
                                            _photo!.locationName!.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          const Divider(height: 1),
                                          const SizedBox(height: 10),
                                          InkWell(
                                            onTap: _openLocationOnMap,
                                            borderRadius: BorderRadius.circular(10),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.place_outlined,
                                                    size: 20,
                                                    color: AppColors.kleinBlue,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _photo!.locationName!,
                                                      style: const TextStyle(
                                                        color: AppColors.kleinBlue,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.open_in_new,
                                                    size: 18,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (_photo!.shootingTips != null &&
                                      _photo!.shootingTips!.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.kleinBlue.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.lightbulb_outline,
                                                size: 18,
                                                color: AppColors.kleinBlue,
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                '拍摄建议',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.kleinBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _photo!.shootingTips!,
                                            style: const TextStyle(
                                              height: 1.5,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
    );
  }
}
