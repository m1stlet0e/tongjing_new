// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`privacy_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:tongjing/theme/app_colors.dart';

/// `PrivacyScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('隐私政策'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          '同镜重视你的隐私。\n\n'
          '本应用会按业务需要处理你主动提供的手机号、昵称、头像、作品与位置等信息，'
          '用于账号服务、内容展示与地图相关功能。具体范围以服务端配置及你使用的功能为准。\n\n'
          '若需正式法律文本，请在上线前由法务补充完整版隐私政策。',
          style: TextStyle(height: 1.5, fontSize: 15),
        ),
      ),
    );
  }
}
