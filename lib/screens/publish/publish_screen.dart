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
  final _tips = TextEditingController();
  final _location = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _tagsInput = TextEditingController();
  final List<Map<String, String>> _selectedTags = [];
  String _tagType = 'scene';

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
    _tips.dispose();
    _location.dispose();
    _lat.dispose();
    _lng.dispose();
    _tagsInput.dispose();
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
        final lat = exif?['latitude'];
        final lng = exif?['longitude'];
        _lat.text = lat == null ? '' : '$lat';
        _lng.text = lng == null ? '' : '$lng';
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

  void _addTagsFromInput() {
    final raw = _tagsInput.text.trim();
    if (raw.isEmpty) return;
    final names = raw
        .split(RegExp(r'[,，\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final name in names) {
      final exists = _selectedTags.any(
        (e) => e['name'] == name && e['type'] == _tagType,
      );
      if (exists) continue;
      if (_selectedTags.length >= 12) break;
      _selectedTags.add({'name': name, 'type': _tagType});
    }
    _tagsInput.clear();
    setState(() {});
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
        shootingTips: _tips.text.trim().isEmpty ? null : _tips.text.trim(),
        locationName: _location.text.trim().isEmpty ? null : _location.text.trim(),
        latitude: double.tryParse(_lat.text.trim()) ??
            (ex?['latitude'] as num?)?.toDouble(),
        longitude: double.tryParse(_lng.text.trim()) ??
            (ex?['longitude'] as num?)?.toDouble(),
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
        tags: _selectedTags,
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
      _tips.clear();
      _lat.clear();
      _lng.clear();
      _tagsInput.clear();
      _selectedTags.clear();
      _step = _Step.select;
    });
  }

  Widget _buildExifCard() {
    final ex = _exifMap() ?? <String, dynamic>{};
    final rows = <(String, String?)>[
      ('设备', ex['camera_model']?.toString()),
      ('镜头', ex['lens_model']?.toString()),
      ('焦段', ex['focal_length']?.toString()),
      ('光圈', ex['aperture']?.toString()),
      ('快门', ex['shutter_speed']?.toString()),
      ('ISO', ex['iso']?.toString()),
      ('白平衡', ex['white_balance']?.toString()),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXIF 参数',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      r.$1,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (r.$2 == null || r.$2!.isEmpty) ? '未识别' : r.$2!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _tagTypeLabel(String type) {
    switch (type) {
      case 'style':
        return '风格';
      case 'gear':
        return '设备';
      default:
        return '场景';
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
                  controller: _tips,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '拍摄 Tips（可选）',
                    hintText: '例如：建议蓝调时段拍摄，长曝光 2s，三脚架稳定',
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lat,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '纬度（可选）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lng,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '经度（可选）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tagsInput,
                  decoration: const InputDecoration(
                    labelText: '标签（可选）',
                    hintText: '多个标签用空格或逗号分隔，例如：夜景 城市 长曝光',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'scene', label: Text('场景')),
                          ButtonSegment(value: 'style', label: Text('风格')),
                          ButtonSegment(value: 'gear', label: Text('设备')),
                        ],
                        selected: {_tagType},
                        onSelectionChanged: (v) {
                          setState(() => _tagType = v.first);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _addTagsFromInput,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.kleinBlue,
                      ),
                      child: const Text('添加'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_selectedTags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _selectedTags
                        .map(
                          (e) => InputChip(
                            label: Text(
                              '#${e['name']} · ${_tagTypeLabel(e['type'] ?? '')}',
                            ),
                            onDeleted: () {
                              setState(() => _selectedTags.remove(e));
                            },
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),
                _buildExifCard(),
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
