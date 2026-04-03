import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/providers/settings_provider.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/utils/top_notice.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  Future<void> _toggleWechatBound() async {
    final settings = context.read<SettingsNotifier>();
    final next = !settings.state.wechatBound;
    await settings.setWechatBound(next);
    if (!mounted) return;
    showTopNotice(context, next ? '微信已绑定（Mock）' : '微信已解绑（Mock）');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final settings = context.watch<SettingsNotifier>();
    final user = auth.user;
    final loginType = AppConfig.enableWechatLogin ? '手机号 / 微信登录' : '手机号验证码登录';
    if (settings.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FF),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        title: const Text('账号与安全'),
        backgroundColor: const Color(0xFFF4F7FF),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _HeaderCard(username: user?.username ?? '未登录', loginType: loginType),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.smartphone_outlined,
            title: '当前登录方式',
            subtitle: loginType,
            actionText: '已启用',
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.wechat_outlined,
            title: '微信账号',
            subtitle: settings.state.wechatBound ? '已绑定微信（Mock）' : '未绑定微信账号',
            actionText: settings.state.wechatBound ? '解绑' : '绑定',
            onTap: _toggleWechatBound,
          ),
          _ActionTile(
            icon: Icons.devices_outlined,
            title: '设备与会话',
            subtitle: '当前活跃设备 ${settings.activeSessionCount} 台',
            actionText: '管理',
            onTap: () => context.push('/settings/device-sessions'),
          ),
          _ActionTile(
            icon: Icons.history_outlined,
            title: '登录记录',
            subtitle: '查看历史登录地点、时间与设备',
            actionText: '查看',
            onTap: () => context.push('/settings/login-history'),
          ),
          _ActionTile(
            icon: Icons.security_outlined,
            title: '会话安全建议',
            subtitle: '请勿泄露验证码，公共设备使用后及时退出',
            actionText: '查看',
            onTap: () => showTopNotice(context, '建议已更新，请按提示保护账号安全'),
          ),
          _ActionTile(
            icon: Icons.lock_clock_outlined,
            title: '登录状态',
            subtitle: auth.isAuthenticated ? '当前设备保持登录' : '当前未登录',
            actionText: auth.isAuthenticated ? '正常' : '未登录',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.username, required this.loginType});

  final String username;
  final String loginType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E2A7B), Color(0xFF1B4FD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '账号安全状态',
            style: TextStyle(color: Color(0xFFD7E3FF), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            username,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            loginType,
            style: const TextStyle(color: Color(0xFFD7E3FF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionText;
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
        subtitle: Text(subtitle),
        trailing: Text(
          actionText,
          style: const TextStyle(color: AppColors.kleinBlue, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
