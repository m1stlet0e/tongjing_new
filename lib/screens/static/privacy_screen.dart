import 'package:flutter/material.dart';
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/support/legal_urls.dart';
import 'package:tongjing/theme/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        title: const Text('隐私政策'),
        backgroundColor: const Color(0xFFF4F7FF),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _TopCard(onOpen: () => openLegalPage(context, AppConfig.legalPrivacyUri, '未配置官网地址')),
          const SizedBox(height: 12),
          const _RuleCard(
            title: '我们收集什么',
            content: '账号信息（手机号或第三方标识）、你主动发布的作品与文案、必要设备日志、经授权的定位信息。',
            icon: Icons.dataset_outlined,
          ),
          const _RuleCard(
            title: '我们如何使用',
            content: '用于登录鉴权、内容展示、功能体验优化与安全风控。不会在未说明情况下出售你的个人信息。',
            icon: Icons.manage_accounts_outlined,
          ),
          const _RuleCard(
            title: '你的控制权',
            content: '你可以管理个人资料、删除发布内容、通过系统权限关闭定位授权，并通过后续客服渠道申请账号相关处理。',
            icon: Icons.gpp_good_outlined,
          ),
        ],
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF102E83), Color(0xFF3A62DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '隐私保护说明',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            '你可以先阅读摘要，再在浏览器查看完整条款。',
            style: TextStyle(color: Color(0xFFD7E3FF)),
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
            ),
            child: const Text('查看完整隐私政策'),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.title,
    required this.content,
    required this.icon,
  });

  final String title;
  final String content;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8FF)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.kleinBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(content, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
