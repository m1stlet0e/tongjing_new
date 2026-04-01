import 'package:flutter/material.dart';
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/support/legal_urls.dart';
import 'package:tongjing/theme/app_colors.dart';

/// 隐私政策（应用内摘要 + 可选跳转官网完整版）。
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('隐私政策'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (AppConfig.legalPrivacyUri != null) ...[
              FilledButton(
                onPressed: () => openLegalPage(
                  context,
                  AppConfig.legalPrivacyUri,
                  '未配置官网地址',
                ),
                child: const Text('在浏览器中查看完整隐私政策'),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              '同镜重视您的个人信息与隐私保护。我们可能根据业务需要处理以下信息：\n\n'
              '· 账号信息：手机号或第三方登录标识，用于注册登录与账号安全。\n'
              '· 您提供的内容：作品、文字、收藏、计划等。\n'
              '· 设备与日志：用于保障服务稳定与安全。\n'
              '· 位置信息：仅在您授权后用于地图、机位等相关功能。\n\n'
              '我们不会在未说明的情况下向无关第三方出售您的个人信息；具体收集范围、使用目的、存储期限、您的权利与联系方式等，以官网《隐私政策》全文为准。',
              style: TextStyle(height: 1.55, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
