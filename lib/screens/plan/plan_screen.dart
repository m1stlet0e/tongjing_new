// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`plan_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/challenge_models.dart';
import 'package:tongjing/models/plan_item.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/plan_store.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/widgets/plan_tab_refresh_scope.dart';

/// `PlanScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

/// `_PlanScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                '计划与挑战',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.kleinBlue,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _chip('我的计划', 0),
                ),
                Expanded(
                  child: _chip('同款挑战', 1),
                ),
              ],
            ),
            Expanded(child: _tab == 0 ? _plansList() : _challengesList()),
          ],
        ),
      ),
    );
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_chip`。
  Widget _chip(String label, int i) {
    final on = _tab == i;
    return InkWell(
      onTap: () {
        if (_tab == i) return;
        setState(() => _tab = i);
        if (i == 0) {
          _loadPlans();
        } else {
          _loadChallenges();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_plansList`。
  Widget _plansList() {
    final auth = context.watch<AuthNotifier>();
    if (_loadingPlans) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!auth.isAuthenticated) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          const Center(child: Text('登录后查看与云端同步的拍摄计划')),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () => context.push('/login'),
              child: const Text('去登录'),
            ),
          ),
        ],
      );
    }
    if (_plans.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('暂无计划，在作品详情页加入拍摄计划')),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPlans,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _plans.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final p = _plans[index];
          return Card(
            child: ListTile(
              title: Text(p.title),
              subtitle: Text(
                '${p.location}\n${p.cameraLine}${p.tips == null || p.tips!.isEmpty ? '' : '\n${p.tips}'}',
                maxLines: 3,
              ),
              isThreeLine: true,
              leading: Checkbox(
                value: p.done,
                onChanged: (v) => _toggleDone(p, v),
              ),
              trailing: FilledButton.tonal(
                onPressed: () => context.go('/map'),
                child: const Text('去打卡'),
              ),
              onTap: p.photoId > 0
                  ? () async {
                      await context.push('/photo/${p.photoId}');
                      if (mounted) await _loadPlans();
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_challengesList`。
  Widget _challengesList() {
    if (_loadingChallenges) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_challenges.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          const Center(child: Text('暂无挑战')),
          TextButton(onPressed: _loadChallenges, child: const Text('刷新')),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _challenges.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final c = _challenges[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                await context.push('/challenges?id=${c.id}');
                if (mounted) await _loadChallenges();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(c.description, style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      '${c.participantCount} 人参与 · 剩余 ${c.daysLeft} 天'
                      '${c.isJoined ? ' · 已参与' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
