// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`plan_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tongjing/theme/app_colors.dart';

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
  int _tab = 0;

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
            Expanded(
              child: _tab == 0 ? _plansList() : _challengesList(),
            ),
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
      onTap: () => setState(() => _tab = i),
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
    final plans = [
      (
        '外滩夜景拍摄',
        '上海·外滩观景台',
        '今天日落前后为黄金时刻，建议携带三脚架。',
      ),
      (
        '世纪公园晨雾',
        '上海·世纪公园',
        '清晨湿度高易有晨雾，中长焦更易出片。',
      ),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = plans[index];
        return Card(
          child: ListTile(
            title: Text(p.$1),
            subtitle: Text('${p.$2}\n${p.$3}', maxLines: 3),
            isThreeLine: true,
            trailing: TextButton(
              onPressed: () => context.push('/my-plans'),
              child: const Text('我的计划'),
            ),
          ),
        );
      },
    );
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_challengesList`。
  Widget _challengesList() {
    final items = [
      ('城市建筑·长焦挑战', '用长焦捕捉建筑线条与光影', 256, 12),
      ('星空·银河挑战', '银河、星轨或星空风景', 128, 28),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final c = items[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/challenges'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(c.$2, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text('${c.$3} 人参与 · 剩余 ${c.$4} 天',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
