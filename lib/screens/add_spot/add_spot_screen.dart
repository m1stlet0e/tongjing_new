// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`add_spot_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/theme/app_colors.dart';

/// `AddSpotScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class AddSpotScreen extends StatefulWidget {
  const AddSpotScreen({super.key});

  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

/// `_AddSpotScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _AddSpotScreenState extends State<AddSpotScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _bestTime = TextEditingController();
  bool _public = true;
  bool _saving = false;

  final _tagOptions = ['城市', '自然', '人像', '星空', '建筑', '街拍', '日落', '日出', '夜景'];
  final Set<String> _tags = {};

  @override
  /// 组件销毁前释放资源，避免监听器或控制器泄漏。
  ///
  /// 方法：`dispose`。
  void dispose() {
    _name.dispose();
    _address.dispose();
    _bestTime.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入机位名称')));
      return;
    }
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    setState(() => _saving = true);
    try {
      await auth.api.spotsCreate(
        name: _name.text.trim(),
        locationName: _address.text.trim(),
        tags: _tags.toList(),
        bestTime: _bestTime.text.trim().isEmpty ? '全天' : _bestTime.text.trim(),
        isPublic: _public,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('添加机位'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '机位名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: '地址 / 位置描述',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bestTime,
            decoration: const InputDecoration(
              labelText: '最佳拍摄时间（可空，默认全天）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('标签（最多选 3 个）', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tagOptions.map((t) {
              final on = _tags.contains(t);
              return FilterChip(
                label: Text(t),
                selected: on,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      if (_tags.length < 3) _tags.add(t);
                    } else {
                      _tags.remove(t);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('公开机位'),
            value: _public,
            onChanged: (v) => setState(() => _public = v),
          ),
        ],
      ),
    );
  }
}
