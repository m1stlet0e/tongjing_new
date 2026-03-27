// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`main_shell` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/widgets/plan_tab_refresh_scope.dart';

/// `MainShell`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _klein = AppColors.kleinBlue;

  /// 与 [StatefulShellBranch] 中「计划」路由的下标一致（0 首页 1 地图 2 发布 3 计划 4 我的）。
  static const int _planBranchIndex = 3;

  final ValueNotifier<int> _planTabActivationTick = ValueNotifier<int>(0);

  @override
  void dispose() {
    _planTabActivationTick.dispose();
    super.dispose();
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(index);
    if (index == _planBranchIndex) {
      _planTabActivationTick.value++;
    }
  }

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    return PlanTabRefreshScope(
      signal: _planTabActivationTick,
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  offset: Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _item(0, Icons.home_outlined, Icons.home, '首页'),
                    _item(1, Icons.map_outlined, Icons.map, '机位'),
                    _publish(),
                    _item(
                      3,
                      Icons.calendar_today_outlined,
                      Icons.calendar_today,
                      '计划',
                    ),
                    _item(4, Icons.person_outline, Icons.person, '我的'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(
    int index,
    IconData outline,
    IconData filled,
    String label,
  ) {
    final selected = widget.navigationShell.currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _goBranch(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? filled : outline,
              size: 22,
              color: selected ? _klein : AppColors.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: selected ? _klein : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_publish`。
  Widget _publish() {
    return Expanded(
      child: InkWell(
        onTap: () => _goBranch(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -10),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _klein,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _klein.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
