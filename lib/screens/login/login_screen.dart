// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`login_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/models/user_model.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/services/cloudbase_gate.dart';
import 'package:tongjing/services/wechat_auth_gate.dart';
import 'package:tongjing/theme/app_colors.dart';

/// `LoginScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// `_LoginScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  int _countdown = 0;
  Timer? _timer;
  bool _sending = false;
  bool _logging = false;
  bool _wechatLogging = false;
  String? _hint;

  @override
  /// 组件销毁前释放资源，避免监听器或控制器泄漏。
  ///
  /// 方法：`dispose`。
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入正确手机号')));
      return;
    }
    if (_countdown > 0) return;
    setState(() => _sending = true);
    try {
      final api = context.read<AuthNotifier>().api;
      String? devCode;
      if (AppConfig.cloudbaseUseNativeAuth) {
        await CloudbaseGate.sendPhoneOtp(phone);
      } else {
        devCode = await api.authSendCode(phone);
      }
      if (!mounted) return;
      setState(() {
        _countdown = 60;
        _hint = null;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_countdown <= 1) {
          t.cancel();
          setState(() => _countdown = 0);
        } else {
          setState(() => _countdown--);
        }
      });
      final msg = AppConfig.cloudbaseUseNativeAuth
          ? '验证码已发送（CloudBase）'
          : ((devCode != null && devCode.isNotEmpty)
              ? '验证码已发送（开发码：$devCode）'
              : '验证码已发送');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _login() async {
    final phone = _phone.text.trim();
    final code = _code.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入正确手机号')));
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入6位验证码')));
      return;
    }
    setState(() => _logging = true);
    try {
      final auth = context.read<AuthNotifier>();
      late final ({UserModel user, String token}) r;
      if (AppConfig.cloudbaseUseNativeAuth) {
        await CloudbaseGate.verifyPhoneOtp(code);
        r = await auth.api.authLoginCloudbasePhone(phone);
      } else {
        r = await auth.api.authLoginPhone(phone, code);
      }
      await auth.login(r.user, r.token);
      if (!mounted) return;
      context.go('/home');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _wechatLogin() async {
    if (_wechatLogging) return;
    setState(() => _wechatLogging = true);
    try {
      final auth = context.read<AuthNotifier>();
      final code = await WechatAuthGate.requestAuthCode();
      final r = await auth.api.authLoginOauth(provider: 'wechat', code: code);
      await auth.login(r.user, r.token);
      if (!mounted) return;
      context.go('/home');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('微信登录失败：${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('微信登录失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _wechatLogging = false);
    }
  }

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              '手机号登录',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '新用户将自动注册',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: const InputDecoration(
                labelText: '手机号',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: OutlinedButton(
                    onPressed: _sending ? null : _sendCode,
                    child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                  ),
                ),
              ],
            ),
            if (_hint != null) ...[
              const SizedBox(height: 8),
              Text(_hint!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _logging ? null : _login,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.kleinBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _logging
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('登录'),
            ),
            if (AppConfig.enableWechatLogin) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _wechatLogging ? null : _wechatLogin,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _wechatLogging
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wechat, color: Color(0xFF07C160)),
                label: Text(_wechatLogging ? '微信登录中...' : '微信登录'),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              AppConfig.cloudbaseUseNativeAuth
                  ? (AppConfig.enableWechatLogin
                      ? '当前使用 CloudBase 原生短信验证码登录，可选微信登录。'
                      : '当前使用 CloudBase 原生短信验证码登录。')
                  : '开发环境：点击“获取验证码”后会在提示里显示开发码。',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
