import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/plan_item.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/plan_store.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/widgets/shoot_plan_widgets.dart';

/// 全屏「我的计划」：与底部「计划」Tab 中列表样式一致（卡片 + 统计条）。
class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({super.key});

  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends State<MyPlansScreen> {
  final _planStore = PlanStore();
  List<PlanItem> _plans = [];
  bool _loading = true;

  int get _doneCount => _plans.where((p) => p.done).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final plans = await _planStore.list(auth.api);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = [];
        _loading = false;
      });
    }
  }

  Future<void> _toggleDone(PlanItem item, bool? value) async {
    final auth = context.read<AuthNotifier>();
    final id = item.planId;
    if (id == null) return;
    try {
      await _planStore.setDone(auth.api, id, value == true);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn =
        context.select<AuthNotifier, bool>((a) => a.isAuthenticated);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的计划'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: !isLoggedIn
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              children: [
                ShootPlanEmptyPanel(
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
            )
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.kleinBlue),
                )
              : _plans.isEmpty
                  ? RefreshIndicator(
                      color: AppColors.kleinBlue,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                        children: const [
                          ShootPlanEmptyPanel(
                            icon: Icons.add_task_rounded,
                            title: '还没有拍摄计划',
                            subtitle: '在作品详情页点击「拍计划」，把想去的机位收进这里。',
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.kleinBlue,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          ShootPlanSummaryBar(
                            total: _plans.length,
                            done: _doneCount,
                          ),
                          const SizedBox(height: 14),
                          ..._plans.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: ShootPlanCard(
                                item: p,
                                onToggleDone: (v) => _toggleDone(p, v),
                                onOpenPhoto: p.photoId > 0
                                    ? () async {
                                        await context.push('/photo/${p.photoId}');
                                        if (mounted) await _load();
                                      }
                                    : null,
                                onOpenMap: () => context.go('/map'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
