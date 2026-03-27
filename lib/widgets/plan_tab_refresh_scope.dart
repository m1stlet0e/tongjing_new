import 'package:flutter/material.dart';

/// 底部栏切换到「计划」Tab 时递增 [signal]，供 [PlanScreen] 监听并拉取最新数据。
class PlanTabRefreshScope extends InheritedWidget {
  const PlanTabRefreshScope({
    super.key,
    required this.signal,
    required super.child,
  });

  final ValueNotifier<int> signal;

  static ValueNotifier<int>? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PlanTabRefreshScope>()?.signal;
  }

  @override
  bool updateShouldNotify(PlanTabRefreshScope oldWidget) => signal != oldWidget.signal;
}
