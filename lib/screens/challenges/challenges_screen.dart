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

/// `ChallengesScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key, this.challengeId});

  final int? challengeId;

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

/// `_ChallengesScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _ChallengesScreenState extends State<ChallengesScreen> {
  ChallengeItem? _item;
  bool _loading = true;
  String? _error;

  @override
  /// 组件初始化阶段执行一次，用于准备首屏数据与监听器。
  ///
  /// 方法：`initState`。
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
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    final item = _item;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('挑战详情'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : item == null
                  ? const Center(child: Text('暂无挑战'))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: item.coverImageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Text('${item.participantCount} 人参与 · 剩余 ${item.daysLeft} 天',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: item.isJoined ? null : _join,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.kleinBlue,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: Text(item.isJoined ? '已参与' : '参与挑战'),
                        ),
                        const SizedBox(height: 24),
                        const Text('热门投稿', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: item.samplePhotos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final p = item.samplePhotos[i];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () => context.push('/photo/${p.photoId}'),
                                  child: CachedNetworkImage(
                                    imageUrl: p.imageUrl,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
