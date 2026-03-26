// 文件说明：主题样式代码，负责统一色彩与视觉规范。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 主题模块：统一定义应用的颜色、字号、样式等视觉规范常量。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';

/// 与原 Expo 客户端一致的克莱因蓝与香槟金
class AppColors {
  AppColors._();

  static const Color kleinBlue = Color(0xFF002FA7);
  static const Color champagneGold = Color(0xFFC9A96E);
  static const Color background = Color(0xFFFAFAFA);
  static const Color cardWhite = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textMuted = Color(0xFF999999);
  static const Color borderLight = Color(0xFFEEEEEE);
}
