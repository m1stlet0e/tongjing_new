// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`photo_detail_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
  final _comment = TextEditingController();

  @override
  /// 组件销毁前释放资源，避免监听器或控制器泄漏。
  ///
  /// 方法：`dispose`。
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

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
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    try {
      await auth.api.photoAddComment(widget.photoId, text);
      _comment.clear();
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已发送')));
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
    try {
      await context.read<AuthNotifier>().api.photoDelete(widget.photoId);
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
                  : CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          pinned: true,
                          backgroundColor: Colors.black,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => context.pop(),
                          ),
                          actions: [
                            if (auth.isAuthenticated &&
                                auth.user?.id == _photo!.userId)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                                onPressed: _delete,
                              ),
                          ],
                        ),
                        SliverToBoxAdapter(
                          child: CachedNetworkImage(
                            imageUrl: _photo!.imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Container(
                            color: AppColors.background,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_photo!.title ?? '未命名',
                                    style: const TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
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
                                        color: _photo!.isFavorited ? AppColors.champagneGold : null,
                                      ),
                                    ),
                                    Text('${_photo!.favoritesCount}'),
                                  ],
                                ),
                                if (_photo!.locationName != null)
                                  Text('地点：${_photo!.locationName}',
                                      style: const TextStyle(color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                                Text(
                                  '参数：${_photo!.cameraBrand ?? ''} ${_photo!.cameraModel ?? ''} '
                                  '${_photo!.focalLength ?? ''} ${_photo!.aperture ?? ''} '
                                  '${_photo!.shutterSpeed ?? ''} ISO${_photo!.iso ?? '-'}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                if (_photo!.description != null &&
                                    _photo!.description!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(_photo!.description!),
                                ],
                                if (_photo!.shootingTips != null &&
                                    _photo!.shootingTips!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text('拍摄建议：${_photo!.shootingTips}'),
                                ],
                                const SizedBox(height: 16),
                                const Text('评论', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _comment,
                                        decoration: const InputDecoration(
                                          hintText: '写评论...',
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _sendComment,
                                      icon: const Icon(Icons.send, color: AppColors.kleinBlue),
                                    ),
                                  ],
                                ),
                                ..._photo!.comments.map(
                                  (c) => ListTile(
                                    dense: true,
                                    title: Text(c.username ?? '用户'),
                                    subtitle: Text(c.content),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
