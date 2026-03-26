// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`publish_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/theme/app_colors.dart';

/// `PublishScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

/// `_PublishScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _PublishScreenState extends State<PublishScreen> {
  final _title = TextEditingController();
  final _caption = TextEditingController();
  final _location = TextEditingController();

  String? _imagePath;
  Map<String, dynamic>? _uploadData;
  bool _busy = false;
  _Step _step = _Step.select;

  @override
  /// 组件销毁前释放资源，避免监听器或控制器泄漏。
  ///
  /// 方法：`dispose`。
  void dispose() {
    _title.dispose();
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('提示'),
          content: const Text('请先登录后再发布'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('去登录')),
          ],
        ),
      );
      if (go == true && mounted) context.push('/login');
      return;
    }

    final p = ImagePicker();
    final x = await p.pickImage(source: src, imageQuality: 90);
    if (x == null) return;
    setState(() {
      _imagePath = x.path;
      _step = _Step.select;
    });
  }

  Future<void> _upload() async {
    final path = _imagePath;
    if (path == null) return;
    final auth = context.read<AuthNotifier>();
    setState(() {
      _busy = true;
      _step = _Step.uploading;
    });
    try {
      final data = await auth.api.uploadImage(path);
      final exif = data['exif'];
      if (exif is Map) {
        final model = exif['camera_model']?.toString();
        if (model != null && model.isNotEmpty) {
          _title.text = '$model 作品';
        }
      }
      setState(() {
        _uploadData = Map<String, dynamic>.from(data);
        _location.text = '未标记机位';
        _step = _Step.edit;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      setState(() => _step = _Step.select);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      setState(() => _step = _Step.select);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic>? _exifMap() {
    final ex = _uploadData?['exif'];
    if (ex is Map<String, dynamic>) return ex;
    if (ex is Map) return Map<String, dynamic>.from(ex);
    return null;
  }

  Future<void> _publish() async {
    if (_uploadData == null) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    final auth = context.read<AuthNotifier>();
    final url = _uploadData!['url']?.toString();
    if (url == null || url.isEmpty) return;

    setState(() => _busy = true);
    try {
      final ex = _exifMap();
      await auth.api.photoPublish(
        imageUrl: url,
        title: title,
        description: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        locationName: _location.text.trim().isEmpty ? null : _location.text.trim(),
        latitude: (ex?['latitude'] as num?)?.toDouble(),
        longitude: (ex?['longitude'] as num?)?.toDouble(),
        exifData: ex == null
            ? null
            : {
                'camera_brand': ex['camera_brand'],
                'camera_model': ex['camera_model'],
                'lens_model': ex['lens_model'],
                'focal_length': ex['focal_length'],
                'aperture': ex['aperture'],
                'shutter_speed': ex['shutter_speed'],
                'iso': ex['iso'],
                'white_balance': ex['white_balance'],
              },
      );
      if (!mounted) return;
      setState(() => _step = _Step.success);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_reset`。
  void _reset() {
    setState(() {
      _imagePath = null;
      _uploadData = null;
      _title.clear();
      _caption.clear();
      _location.clear();
      _step = _Step.select;
    });
  }

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('发布作品'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: switch (_step) {
        _Step.success => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 72),
                  const SizedBox(height: 16),
                  const Text('发布成功', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      _reset();
                      context.go('/home');
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.kleinBlue),
                    child: const Text('返回首页'),
                  ),
                ],
              ),
            ),
          ),
        _Step.uploading => const Center(child: CircularProgressIndicator()),
        _Step.edit => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _caption,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: '地点 / 机位',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _publish,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.kleinBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('确认发布'),
                ),
              ],
            ),
          ),
        _Step.select => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_imagePath != null)
                  Text('已选择图片，点击下方上传', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('从相册选择'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('拍照'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: (_busy || _imagePath == null) ? null : _upload,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.kleinBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('上传并填写信息'),
                ),
              ],
            ),
          ),
      },
    );
  }
}

/// `_Step`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
enum _Step { select, uploading, edit, success }
