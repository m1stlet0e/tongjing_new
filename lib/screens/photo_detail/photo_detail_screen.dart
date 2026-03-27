// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`photo_detail_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/services/plan_store.dart';
import 'package:tongjing/theme/app_colors.dart';

/// `PhotoDetailScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({super.key, required this.photoId});

  final int photoId;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

/// `_PhotoDetailScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  final _planStore = PlanStore();
  PhotoDetail? _photo;
  bool _loading = true;
  String? _error;
  bool _inPlan = false;

  @override
  /// 组件初始化阶段执行一次，用于准备首屏数据与监听器。
  ///
  /// 方法：`initState`。
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (widget.photoId <= 0) return;
    if (AppConfig.useMockData) {
      setState(() {
        _loading = false;
        _error = null;
        _photo = _buildMockDetail(widget.photoId);
      });
      await _syncPlanFlag();
      return;
    }
    if (_isMockId(widget.photoId)) {
      setState(() {
        _loading = false;
        _error = null;
        _photo = _buildMockDetail(widget.photoId);
      });
      await _syncPlanFlag();
      return;
    }
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

  Future<void> _syncPlanFlag() async {
    final p = _photo;
    if (p == null) return;
    final has = await _planStore.containsPhoto(p.id);
    if (mounted) setState(() => _inPlan = has);
  }

  bool _isMockId(int id) => id >= 90000;

  Future<void> _addToPlan() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      if (mounted) context.push('/login');
      return;
    }
    final p = _photo;
    if (p == null) return;
    await _planStore.upsert(
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
    if (!mounted) return;
    setState(() => _inPlan = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已加入拍摄计划'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => context.push('/my-plans'),
        ),
      ),
    );
  }

  PhotoDetail _buildMockDetail(int id) {
    switch (id) {
      case 90001:
      case 99001:
        return PhotoDetail(
          id: id,
          imageUrl:
              'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1600&q=80',
          title: '外滩蓝调时刻（Mock）',
          description: '这是一条本地 Mock 数据，用于演示详情页排版与交互。',
          locationName: '上海外滩观景台',
          cameraBrand: 'Sony',
          cameraModel: 'A7M4',
          focalLength: '50mm',
          aperture: '1.8',
          shutterSpeed: '1/125',
          iso: 320,
          username: 'MockCreator',
          likesCount: 128,
          favoritesCount: 38,
          commentsCount: 2,
          shootingTips: '建议日落后 20 分钟拍摄，保留天空层次。',
          latitude: 31.2400,
          longitude: 121.4900,
          tags: [PhotoTag(name: '夜景', type: 'scene')],
          comments: [
            PhotoComment(id: 1, content: '色彩很通透，学习了', username: '用户A'),
            PhotoComment(id: 2, content: '这个机位太稳了', username: '用户B'),
          ],
        );
      case 90002:
      case 99002:
        return PhotoDetail(
          id: id,
          imageUrl:
              'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1600&q=80',
          title: '城市夜景长曝光（Mock）',
          description: '使用三脚架和低 ISO 获取干净夜景画面。',
          locationName: '陆家嘴滨江',
          cameraBrand: 'Canon',
          cameraModel: 'R6',
          focalLength: '24-70mm',
          aperture: '8',
          shutterSpeed: '4s',
          iso: 100,
          username: 'MockCreator',
          likesCount: 96,
          favoritesCount: 24,
          commentsCount: 1,
          shootingTips: '车流方向尽量平行于画面，光轨更有引导性。',
          latitude: 31.2350,
          longitude: 121.5070,
          tags: [PhotoTag(name: '长曝光', type: 'style')],
          comments: [
            PhotoComment(id: 3, content: '参数很实用', username: '用户C'),
          ],
        );
      default:
        return PhotoDetail(
          id: id,
          imageUrl:
              'https://images.unsplash.com/photo-1482192596544-9eb780fc7f66?auto=format&fit=crop&w=1600&q=80',
          title: '机位示例（Mock）',
          description: '本地模拟详情数据。',
          locationName: '武康路',
          cameraBrand: 'Fujifilm',
          cameraModel: 'X-T5',
          focalLength: '35mm',
          aperture: '2.0',
          shutterSpeed: '1/250',
          iso: 200,
          username: 'MockCreator',
          likesCount: 66,
          favoritesCount: 12,
          commentsCount: 0,
          shootingTips: '避开人流高峰，侧逆光更出层次。',
          latitude: 31.2044,
          longitude: 121.4338,
        );
    }
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
          final delta = liked ? 1 : -1;
          _photo = PhotoDetail(
            id: _photo!.id,
            imageUrl: _photo!.imageUrl,
            title: _photo!.title,
            description: _photo!.description,
            locationName: _photo!.locationName,
            cameraModel: _photo!.cameraModel,
            focalLength: _photo!.focalLength,
            aperture: _photo!.aperture,
            shutterSpeed: _photo!.shutterSpeed,
            iso: _photo!.iso,
            username: _photo!.username,
            avatarUrl: _photo!.avatarUrl,
            likesCount: (_photo!.likesCount + delta).clamp(0, 1 << 30),
            commentsCount: _photo!.commentsCount,
            favoritesCount: _photo!.favoritesCount,
            tags: _photo!.tags,
            isLiked: liked,
            isFavorited: _photo!.isFavorited,
            latitude: _photo!.latitude,
            longitude: _photo!.longitude,
            cameraBrand: _photo!.cameraBrand,
            userBio: _photo!.userBio,
            shootingTips: _photo!.shootingTips,
            userId: _photo!.userId,
            comments: _photo!.comments,
          );
        }
      });
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
      if (fav && _photo != null) {
        await _planStore.upsert(
          PlanItem(
            photoId: _photo!.id,
            title: _photo!.title ?? '未命名拍摄计划',
            location: _photo!.locationName ?? '未标记机位',
            imageUrl: _photo!.imageUrl,
            cameraLine:
                '${_photo!.cameraModel ?? '-'} | ${_photo!.focalLength ?? '-'} | f/${_photo!.aperture ?? '-'}',
            tips: _photo!.shootingTips,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
      }
      setState(() {
        if (_photo != null) {
          _photo = PhotoDetail(
            id: _photo!.id,
            imageUrl: _photo!.imageUrl,
            title: _photo!.title,
            description: _photo!.description,
            locationName: _photo!.locationName,
            cameraModel: _photo!.cameraModel,
            focalLength: _photo!.focalLength,
            aperture: _photo!.aperture,
            shutterSpeed: _photo!.shutterSpeed,
            iso: _photo!.iso,
            username: _photo!.username,
            avatarUrl: _photo!.avatarUrl,
            likesCount: _photo!.likesCount,
            commentsCount: _photo!.commentsCount,
            favoritesCount: _photo!.favoritesCount,
            tags: _photo!.tags,
            isLiked: _photo!.isLiked,
            isFavorited: fav,
            latitude: _photo!.latitude,
            longitude: _photo!.longitude,
            cameraBrand: _photo!.cameraBrand,
            userBio: _photo!.userBio,
            shootingTips: _photo!.shootingTips,
            userId: _photo!.userId,
            comments: _photo!.comments,
          );
        }
      });
      if (fav && mounted) {
        setState(() => _inPlan = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('收藏成功，已同步到拍摄计划'),
            action: SnackBarAction(
              label: '查看',
              onPressed: () => context.push('/my-plans'),
            ),
          ),
        );
      }
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
    context.pop();
  }

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
              : _photo == null
                  ? const SizedBox.shrink()
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: CachedNetworkImage(
                              imageUrl: _photo!.imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 8,
                          left: 8,
                          right: 8,
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
                              if (auth.isAuthenticated && auth.user?.id == _photo!.userId)
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
                          initialChildSize: 0.2,
                          minChildSize: 0.14,
                          maxChildSize: 0.72,
                          builder: (context, controller) {
                            return Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                              ),
                              child: ListView(
                                controller: controller,
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                                children: [
                                  Center(
                                    child: Container(
                                      width: 44,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD7D7D7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _photo!.title ?? '未命名',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '作者：${_photo!.username ?? '匿名作者'}',
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  ),
                                  if (_photo!.description != null &&
                                      _photo!.description!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(_photo!.description!),
                                  ],
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: _like,
                                        icon: Icon(
                                          _photo!.isLiked ? Icons.favorite : Icons.favorite_border,
                                          color: _photo!.isLiked ? Colors.red : null,
                                        ),
                                      ),
                                      Text('${_photo!.likesCount}'),
                                      const SizedBox(width: 16),
                                      IconButton(
                                        onPressed: _favorite,
                                        icon: Icon(
                                          _photo!.isFavorited ? Icons.star : Icons.star_border,
                                          color: _photo!.isFavorited
                                              ? AppColors.champagneGold
                                              : null,
                                        ),
                                      ),
                                      Text('${_photo!.favoritesCount}'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (_inPlan)
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => context.push('/my-plans'),
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: const Text('已在拍摄计划中'),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.kleinBlue,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        onPressed: _addToPlan,
                                        icon: const Icon(Icons.add_task),
                                        label: const Text('加入拍摄计划'),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '参数信息',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${_photo!.cameraBrand ?? ''} ${_photo!.cameraModel ?? ''}',
                                        ),
                                        Text(
                                          '${_photo!.focalLength ?? '-'} | f/${_photo!.aperture ?? '-'} | ${_photo!.shutterSpeed ?? '-'} | ISO ${_photo!.iso ?? '-'}',
                                        ),
                                        if (_photo!.locationName != null &&
                                            _photo!.locationName!.isNotEmpty)
                                          Text('机位：${_photo!.locationName}'),
                                      ],
                                    ),
                                  ),
                                  if (_photo!.shootingTips != null &&
                                      _photo!.shootingTips!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF4FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '拍摄 Tips',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.kleinBlue,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(_photo!.shootingTips!),
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
