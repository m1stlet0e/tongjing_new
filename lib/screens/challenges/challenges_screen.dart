// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`challenges_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/challenge_models.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/utils/remote_image.dart';

/// `ChallengesScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key, this.challengeId});

  final int? challengeId;

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  ChallengeItem? _item;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthNotifier>().api;
      ChallengeItem detail;
      if (widget.challengeId != null && widget.challengeId! > 0) {
        detail = await api.challengeDetail(widget.challengeId!);
      } else {
        final list = await api.challengesList();
        if (list.isEmpty) {
          throw ApiException('暂无挑战');
        }
        detail = list.first;
      }
      if (!mounted) return;
      setState(() {
        _item = detail;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    final item = _item;
    if (item == null || item.isJoined) return;
    try {
      await auth.api.challengeJoin(item.id);
      if (!mounted) return;
      final fresh = await auth.api.challengeDetail(item.id);
      if (!mounted) return;
      setState(() => _item = fresh);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('参与成功')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load, topInset: top)
              : item == null
                  ? _ErrorBody(message: '暂无挑战', onRetry: _load, topInset: top)
                  : _ChallengeDetailBody(
                      item: item,
                      topInset: top,
                      onRefresh: _load,
                      onJoin: _join,
                    ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.topInset,
  });

  final String message;
  final VoidCallback onRetry;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.travel_explore_outlined,
                      size: 56,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('重试'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.kleinBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeDetailBody extends StatelessWidget {
  const _ChallengeDetailBody({
    required this.item,
    required this.topInset,
    required this.onRefresh,
    required this.onJoin,
  });

  final ChallengeItem item;
  final double topInset;
  final Future<void> Function() onRefresh;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final hasCover = item.coverImageUrl.trim().isNotEmpty;

    return RefreshIndicator(
      color: AppColors.kleinBlue,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (hasCover)
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: CachedNetworkImage(
                      imageUrl: item.coverImageUrl,
                      httpHeaders: kRemoteImageHttpHeaders,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF1A2744),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white38,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF1A2744),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 200,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0D1B4D),
                          AppColors.kleinBlue,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.emoji_events_rounded,
                          color: Colors.white24, size: 64),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: hasCover ? 120 : 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: hasCover ? 0.75 : 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: topInset + 4,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.isJoined)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.champagneGold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, color: Color(0xFF3D2E0A), size: 16),
                              SizedBox(width: 4),
                              Text(
                                '你已参与',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF3D2E0A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(
                                icon: Icons.groups_rounded,
                                label: '${item.participantCount} 人参与',
                                emphasized: true,
                              ),
                              _MetaChip(
                                icon: Icons.event_available_rounded,
                                label: '剩余 ${item.daysLeft} 天',
                              ),
                              _MetaChip(
                                icon: Icons.collections_bookmark_outlined,
                                label: '投稿示例 ${item.samplePhotos.length} 张',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Icon(Icons.article_outlined,
                                  size: 18, color: AppColors.kleinBlue),
                              SizedBox(width: 6),
                              Text(
                                '活动说明',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.55,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: item.isJoined ? null : onJoin,
                              icon: Icon(
                                item.isJoined ? Icons.check_circle_outline_rounded : Icons.how_to_reg_rounded,
                                size: 22,
                              ),
                              label: Text(
                                item.isJoined ? '已参与本挑战' : '参与挑战',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: item.isJoined
                                    ? AppColors.textMuted
                                    : AppColors.kleinBlue,
                                disabledBackgroundColor: AppColors.textMuted.withValues(alpha: 0.35),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              item.isJoined
                                  ? '可继续在首页发布作品参与话题'
                                  : '登录后即可一键报名（未登录将跳转登录页）',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.kleinBlue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '热门投稿',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '点击查看大图',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (item.samplePhotos.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: const Text(
                          '暂无示例投稿',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    else
                      SizedBox(
                        height: 156,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: item.samplePhotos.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final p = item.samplePhotos[i];
                            return _SamplePhotoTile(photo: p);
                          },
                        ),
                      ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.kleinBlue.withValues(alpha: 0.1)
            : const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasized
              ? AppColors.kleinBlue.withValues(alpha: 0.25)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: emphasized ? AppColors.kleinBlue : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              color: emphasized ? AppColors.kleinBlue : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SamplePhotoTile extends StatelessWidget {
  const _SamplePhotoTile({required this.photo});

  final ChallengeSamplePhoto photo;

  @override
  Widget build(BuildContext context) {
    final title = photo.title.trim().isEmpty ? '投稿作品' : photo.title;

    return SizedBox(
      width: 112,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/photo/${photo.photoId}'),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: photo.imageUrl,
                    httpHeaders: kRemoteImageHttpHeaders,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFE8EBF2),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFE8EBF2),
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
