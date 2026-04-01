import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/support/legal_urls.dart';
import 'package:tongjing/theme/app_colors.dart';

/// 关于同镜：版本号、简介与官网入口。
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _info = i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ver = _info == null ? '…' : '${_info!.version}（${_info!.buildNumber}）';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('关于同镜'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '同镜',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.kleinBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '版本 $ver',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            const Text(
              '同镜是面向摄影爱好者与创作者的社区与机位工具类应用，支持作品浏览与发布、地图机位探索、拍摄计划与个人内容管理。数据服务基于腾讯云开发（CloudBase）。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.55),
            ),
            const SizedBox(height: 28),
            if (AppConfig.legalHomeUri != null)
              OutlinedButton(
                onPressed: () => openLegalPage(
                  context,
                  AppConfig.legalHomeUri,
                  '未配置官网地址',
                ),
                child: const Text('访问官方网站'),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => openLegalPage(
                context,
                AppConfig.legalPrivacyUri,
                '上架请在构建参数中配置 LEGAL_SITE_BASE（HTTPS 官网根地址）',
              ),
              child: const Text('隐私政策'),
            ),
            TextButton(
              onPressed: () => openLegalPage(
                context,
                AppConfig.legalTermsUri,
                '上架请在构建参数中配置 LEGAL_SITE_BASE（HTTPS 官网根地址）',
              ),
              child: const Text('用户协议'),
            ),
          ],
        ),
      ),
    );
  }
}
