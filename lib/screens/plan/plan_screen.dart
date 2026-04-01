// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`plan_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/challenge_models.dart';
import 'package:tongjing/models/plan_item.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/plan_store.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/utils/remote_image.dart';
import 'package:tongjing/widgets/plan_tab_refresh_scope.dart';

/// `PlanScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _planStore = PlanStore();
  List<PlanItem> _plans = [];
  List<ChallengeItem> _challenges = [];
  bool _loadingPlans = true;
  bool _loadingChallenges = true;
  int _tab = 0;

  ValueNotifier<int>? _planTabSignal;
  void _onPlanTabTick() {
    _loadPlans();
    _loadChallenges();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlans();
      _loadChallenges();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PlanTabRefreshScope.maybeOf(context);
    if (!identical(next, _planTabSignal)) {
      _planTabSignal?.removeListener(_onPlanTabTick);
      _planTabSignal = next;
      _planTabSignal?.addListener(_onPlanTabTick);
    }
  }

  @override
  void dispose() {
    _planTabSignal?.removeListener(_onPlanTabTick);
    super.dispose();
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() => _loadingPlans = true);
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      if (mounted) {
        setState(() {
          _plans = [];
          _loadingPlans = false;
        });
      }
      return;
    }
    try {
      final plans = await _planStore.list(auth.api);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = [];
        _loadingPlans = false;
      });
    }
  }

  Future<void> _toggleDone(PlanItem item, bool? value) async {
    final auth = context.read<AuthNotifier>();
    final id = item.planId;
    if (!auth.isAuthenticated || id == null) return;
    try {
      await _planStore.setDone(auth.api, id, value == true);
      await _loadPlans();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$e')),
      );
    }
  }

  Future<void> _loadChallenges() async {
    if (!mounted) return;
    setState(() => _loadingChallenges = true);
    try {
      final auth = context.read<AuthNotifier>();
      final list = await auth.api.challengesList();
      if (!mounted) return;
      setState(() {
        _challenges = list;
        _loadingChallenges = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _challenges = [];
        _loadingChallenges = false;
      });
    }
  }

  int get _donePlanCount => _plans.where((p) => p.done).length;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlanHeroHeader(topInset: top),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _SegmentTabs(
              tab: _tab,
              onChanged: (i) {
                if (_tab == i) return;
                setState(() => _tab = i);
                if (i == 0) {
                  _loadPlans();
                } else {
                  _loadChallenges();
                }
              },
            ),
          ),
          Expanded(child: _tab == 0 ? _plansList() : _challengesList()),
        ],
      ),
    );
  }

  Widget _plansList() {
    final isLoggedIn =
        context.select<AuthNotifier, bool>((a) => a.isAuthenticated);
    if (_loadingPlans) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!isLoggedIn) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 48),
          _EmptyPanel(
            icon: Icons.lock_outline_rounded,
            title: '登录后同步拍摄计划',
            subtitle: '在作品详情页可将机位加入计划，登录后与云端保持一致。',
            action: FilledButton(
              onPressed: () => context.push('/login'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.kleinBlue,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              child: const Text('去登录'),
            ),
          ),
        ],
      );
    }
    if (_plans.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: const [
          SizedBox(height: 48),
          _EmptyPanel(
            icon: Icons.add_task_rounded,
            title: '还没有拍摄计划',
            subtitle: '在作品详情页点击「拍计划」，把想去的机位收进这里。',
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: AppColors.kleinBlue,
      onRefresh: _loadPlans,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _PlanSummaryBar(
            total: _plans.length,
            done: _donePlanCount,
          ),
          const SizedBox(height: 14),
          ..._plans.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _PlanCard(
                  item: p,
                  onToggleDone: (v) => _toggleDone(p, v),
                  onOpenPhoto: p.photoId > 0
                      ? () async {
                          await context.push('/photo/${p.photoId}');
                          if (mounted) await _loadPlans();
                        }
                      : null,
                  onOpenMap: () => context.go('/map'),
                ),
              )),
        ],
      ),
    );
  }

  Widget _challengesList() {
    if (_loadingChallenges) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_challenges.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 48),
          _EmptyPanel(
            icon: Icons.emoji_events_outlined,
            title: '暂无挑战活动',
            subtitle: '有新活动时将展示在这里，可先逛逛首页与地图。',
            action: OutlinedButton.icon(
              onPressed: _loadChallenges,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('刷新'),
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: AppColors.kleinBlue,
      onRefresh: _loadChallenges,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _challenges.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final c = _challenges[index];
          return _ChallengeListCard(
            item: c,
            onTap: () async {
              await context.push('/challenges?id=${c.id}');
              if (mounted) await _loadChallenges();
            },
          );
        },
      ),
    );
  }
}

class _PlanHeroHeader extends StatelessWidget {
  const _PlanHeroHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D1B4D),
            AppColors.kleinBlue,
            Color(0xFF1E4DB7),
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33002FA7),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '计划与挑战',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '整理拍摄路线 · 参与同款挑战',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFB8C8F0),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({
    required this.tab,
    required this.onChanged,
  });

  final int tab;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegButton(
              label: '我的计划',
              icon: Icons.checklist_rtl_rounded,
              selected: tab == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegButton(
              label: '同款挑战',
              icon: Icons.military_tech_rounded,
              selected: tab == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.kleinBlue.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.kleinBlue.withValues(alpha: 0.35) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.kleinBlue : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                  color: selected ? AppColors.kleinBlue : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanSummaryBar extends StatelessWidget {
  const _PlanSummaryBar({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatTile(
            label: '进行中',
            value: '${total - done}',
            icon: Icons.timelapse_rounded,
            tint: AppColors.kleinBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatTile(
            label: '已完成',
            value: '$done',
            icon: Icons.task_alt_rounded,
            tint: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatTile(
            label: '合计',
            value: '$total',
            icon: Icons.list_alt_rounded,
            tint: AppColors.champagneGold,
          ),
        ),
      ],
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  const _MiniStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.item,
    required this.onToggleDone,
    required this.onOpenPhoto,
    required this.onOpenMap,
  });

  final PlanItem item;
  final ValueChanged<bool?> onToggleDone;
  final VoidCallback? onOpenPhoto;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl.trim().isNotEmpty;
    final hasTips = item.tips != null && item.tips!.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onOpenPhoto,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            httpHeaders: kRemoteImageHttpHeaders,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFEDEEF2),
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFEDEEF2),
                              child: const Icon(Icons.image_not_supported_outlined,
                                  color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEEF2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.photo_camera_outlined,
                            color: AppColors.textMuted, size: 32),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(4, -4),
                                child: Checkbox(
                                  value: item.done,
                                  activeColor: AppColors.kleinBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  onChanged: onToggleDone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _InfoLine(
                            icon: Icons.place_outlined,
                            text: item.location,
                          ),
                          const SizedBox(height: 4),
                          _InfoLine(
                            icon: Icons.tune_rounded,
                            text: item.cameraLine,
                          ),
                          if (item.createdAt.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _InfoLine(
                              icon: Icons.schedule_rounded,
                              text: '添加时间 ${item.createdAt.length > 16 ? item.createdAt.substring(0, 16) : item.createdAt}',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasTips) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.kleinBlue.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 18,
                          color: AppColors.kleinBlue.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.tips!,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (onOpenPhoto != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onOpenPhoto,
                          icon: const Icon(Icons.photo_outlined, size: 18),
                          label: const Text('查看作品'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.kleinBlue,
                            side: BorderSide(color: AppColors.kleinBlue.withValues(alpha: 0.45)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (onOpenPhoto != null) const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOpenMap,
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text('去打卡'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.kleinBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChallengeListCard extends StatelessWidget {
  const _ChallengeListCard({
    required this.item,
    required this.onTap,
  });

  final ChallengeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasCover = item.coverImageUrl.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasCover)
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 2.4,
                      child: CachedNetworkImage(
                        imageUrl: item.coverImageUrl,
                        httpHeaders: kRemoteImageHttpHeaders,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFFE8EBF2),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFE8EBF2),
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported_outlined,
                              color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.groups_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${item.participantCount} 人参与',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (item.isJoined)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.champagneGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.champagneGold.withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Text(
                              '已参与',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8B6914),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChipPill(
                          icon: Icons.timer_outlined,
                          label: '剩余 ${item.daysLeft} 天',
                        ),
                        _ChipPill(
                          icon: Icons.photo_library_outlined,
                          label: '${item.samplePhotos.length} 幅投稿示例',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Text(
                          '查看详情',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.kleinBlue,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: AppColors.kleinBlue),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 22),
            action!,
          ],
        ],
      ),
    );
  }
}
