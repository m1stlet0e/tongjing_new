// 文件说明：颜色系统定义，统一应用中使用的颜色常量。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 主题模块：统一定义应用的颜色、字号、样式等视觉规范常量。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';

/// 与原 Expo 客户端一致的克莱因蓝与香槟金
class AppColors {
  AppColors._();

  // === 主品牌色 ===
  static const Color kleinBlue = Color(0xFF002FA7);
  static const Color champagneGold = Color(0xFFC9A96E);

  // === 背景色 ===
  static const Color background = Color(0xFFFAFAFA);
  static const Color cardWhite = Colors.white;

  // === 文字色 ===
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textMuted = Color(0xFF999999);

  // === 边框色 ===
  static const Color borderLight = Color(0xFFEEEEEE);

  // === 功能色 ===
  /// 错误 / 危险
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFF1F1);
  static const Color errorLighter = Color(0xFFFFD6D6);

  /// 成功
  static const Color success = Color(0xFF43A047);
  static const Color successLight = Color(0xFFE8F5E9);

  /// 警告
  static const Color warning = Color(0xFFFFA000);
  static const Color warningLight = Color(0xFFFFF8E1);

  /// 信息
  static const Color info = Color(0xFF1E88E5);
  static const Color infoLight = Color(0xFFE3F2FD);

  // === 交互状态色 ===
  /// 点赞（红色）
  static const Color like = Color(0xFFE53935);

  /// 收藏（香槟金）
  static const Color favorite = champagneGold;

  // === 渐变色 ===
  /// 启动页渐变起始色
  static const Color splashStart = Color(0xFF0E2A7B);

  /// 启动页渐变结束色
  static const Color splashEnd = Color(0xFF1E4AB8);

  /// 个人页封面渐变
  static const Color profileHeaderStart = Color(0xFF0E2A7B);
  static const Color profileHeaderEnd = Color(0xFF3D6BC9);

  // === 遮罩色 ===
  static const Color overlayDark = Color(0x66000000);
  static const Color overlayLight = Color(0x08FFFFFF);

  // === 占位图色 ===
  static const Color placeholder = Color(0xFFEEEEEE);
  static const Color placeholderLight = Color(0xFFF3F5FA);

  // === 分割线色 ===
  static const Color divider = Color(0xFFE2E8F0);

  // === 禁用状态 ===
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color disabledBackground = Color(0xFFF5F5F5);
}
