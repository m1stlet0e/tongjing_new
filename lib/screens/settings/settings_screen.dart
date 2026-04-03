import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/theme/app_spacing.dart';
import 'package:tongjing/theme/app_typography.dart';
import 'package:tongjing/theme/app_shapes.dart';
import 'package:tongjing/utils/top_notice.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后可再次通过手机号或微信登录。确定退出吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('退出')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AuthNotifier>().logout();
    if (!context.mounted) return;
    showTopNotice(context, '已退出当前账号');
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('设置中心'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.sm,
          AppSpacing.xxl,
          AppSpacing.huge,
        ),
        children: [
          _SectionCard(
            title: '个人资料',
            subtitle: '头像、昵称、器材与创作信息',
            items: [
              _CellData(
                icon: Icons.person_outline,
                title: '编辑资料',
                subtitle: '修改头像、昵称与简介',
                onTap: () => context.push('/edit-profile'),
              ),
              _CellData(
                icon: Icons.photo_camera_outlined,
                title: '我的器材',
                subtitle: '维护机身、镜头与常用设备',
                onTap: () => context.push('/my-equipment'),
              ),
            ],
          ),
          AppSpacing.verticalMd,
          _SectionCard(
            title: '账号与安全',
            subtitle: '登录方式、会话管理与安全建议',
            items: [
              _CellData(
                icon: Icons.notifications_active_outlined,
                title: '通知与提醒',
                subtitle: '点赞评论、粉丝与计划提醒开关',
                onTap: () => context.push('/settings/notifications'),
              ),
              _CellData(
                icon: Icons.tune_outlined,
                title: '通用偏好',
                subtitle: '播放、画质、流量与缓存策略',
                onTap: () => context.push('/settings/preferences'),
              ),
              _CellData(
                icon: Icons.verified_user_outlined,
                title: '账号与安全',
                subtitle: '查看登录方式与安全状态',
                onTap: () => context.push('/account-security'),
              ),
            ],
          ),
          AppSpacing.verticalMd,
          _SectionCard(
            title: '协议与说明',
            subtitle: '查看应用说明与法律文档',
            items: [
              _CellData(
                icon: Icons.info_outline,
                title: '关于同镜',
                subtitle: '版本信息、产品介绍',
                onTap: () => context.push('/about'),
              ),
              _CellData(
                icon: Icons.policy_outlined,
                title: '隐私政策',
                subtitle: '个人信息处理规则',
                onTap: () => context.push('/privacy'),
              ),
              _CellData(
                icon: Icons.description_outlined,
                title: '用户协议',
                subtitle: '平台服务条款说明',
                onTap: () => context.push('/terms'),
              ),
            ],
          ),
          AppSpacing.verticalLg,
          Card(
            elevation: 0,
            color: AppColors.errorLight,
            shape: RoundedRectangleBorder(
              borderRadius: AppShapes.radiusXxlAll,
              side: const BorderSide(color: AppColors.errorLighter),
            ),
            child: ListTile(
              onTap: () => _logout(context),
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                '退出登录',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text('仅退出当前设备，不会删除账号数据'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<_CellData> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppShapes.radiusHuge),
        gradient: const LinearGradient(
          colors: [AppColors.infoLight, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.infoLight.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxs,
                AppSpacing.xxs,
                AppSpacing.xxs,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.cardTitle,
                  ),
                  AppSpacing.verticalXs,
                  Text(
                    subtitle,
                    style: AppTypography.secondarySmall,
                  ),
                ],
              ),
            ),
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SettingsCell(data: e),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCell extends StatelessWidget {
  const _SettingsCell({required this.data});

  final _CellData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppShapes.radiusXxlAll,
      child: InkWell(
        borderRadius: AppShapes.radiusXxlAll,
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: AppShapes.radiusSmAll,
                ),
                child: Icon(data.icon, color: AppColors.kleinBlue, size: 19),
              ),
              AppSpacing.horizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    AppSpacing.verticalXs,
                    Text(
                      data.subtitle,
                      style: AppTypography.secondarySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CellData {
  const _CellData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
