import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/support/legal_urls.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/utils/top_notice.dart';

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
    final version = _info == null ? '...' : '${_info!.version}+${_info!.buildNumber}';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        title: const Text('关于同镜'),
        backgroundColor: const Color(0xFFF4F7FF),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF0C2F79), Color(0xFF2B59D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '同镜 Tongjing',
                  style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '版本 $version',
                  style: const TextStyle(color: Color(0xFFD7E3FF)),
                ),
                const SizedBox(height: 10),
                const Text(
                  '为摄影创作者打造的内容社区与机位工具。',
                  style: TextStyle(color: Color(0xFFD7E3FF), height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ActionItem(
            icon: Icons.copy_all_outlined,
            title: '复制版本号',
            subtitle: version,
            onTap: () {
              Clipboard.setData(ClipboardData(text: version));
              showTopNotice(context, '版本号已复制');
            },
          ),
          _ActionItem(
            icon: Icons.language_outlined,
            title: '访问官网',
            subtitle: AppConfig.legalHomeUri?.toString() ?? '未配置',
            onTap: () => openLegalPage(context, AppConfig.legalHomeUri, '未配置官网地址'),
          ),
          _ActionItem(
            icon: Icons.policy_outlined,
            title: '隐私政策',
            subtitle: '查看完整隐私条款',
            onTap: () => openLegalPage(
              context,
              AppConfig.legalPrivacyUri,
              '上架请配置 LEGAL_SITE_BASE',
            ),
          ),
          _ActionItem(
            icon: Icons.description_outlined,
            title: '用户协议',
            subtitle: '查看完整服务协议',
            onTap: () => openLegalPage(
              context,
              AppConfig.legalTermsUri,
              '上架请配置 LEGAL_SITE_BASE',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8FF)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.kleinBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ),
    );
  }
}
