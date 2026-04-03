// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`publish_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/analytics_service.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/services/publish_draft_store.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/theme/app_spacing.dart';
import 'package:tongjing/theme/app_typography.dart';
import 'package:tongjing/theme/app_shapes.dart';
import 'package:tongjing/utils/photo_recipe_display.dart';

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
  final _draftStore = PublishDraftStore();
  final _title = TextEditingController();
  final _caption = TextEditingController();
  final _tips = TextEditingController();
  final _location = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _tagsInput = TextEditingController();
  final List<Map<String, String>> _selectedTags = [];
  String _tagType = 'scene';
  String _aiCopyHint = '点击 AI 帮我写，生成拍摄文案建议';

  String? _imagePath;
  Map<String, dynamic>? _uploadData;
  bool _busy = false;
  _Step _step = _Step.select;
  bool _hasLocalDraft = false;
  String? _draftSavedAtLabel;
  String? _lastUploadError;
  Timer? _autoSaveDebounce;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onDraftFieldChanged);
    _caption.addListener(_onDraftFieldChanged);
    _tips.addListener(_onDraftFieldChanged);
    _location.addListener(_onDraftFieldChanged);
    _lat.addListener(_onDraftFieldChanged);
    _lng.addListener(_onDraftFieldChanged);
    _tagsInput.addListener(_onDraftFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshDraftFlag());
  }

  Future<void> _refreshDraftFlag() async {
    final draft = await _draftStore.load();
    if (!mounted) return;
    final url = draft?['image_url']?.toString() ?? '';
    final rawSavedAt = draft?['saved_at']?.toString();
    String? savedLabel;
    if (rawSavedAt != null && rawSavedAt.isNotEmpty) {
      final dt = DateTime.tryParse(rawSavedAt)?.toLocal();
      if (dt != null) {
        savedLabel =
            '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }
    setState(() {
      _hasLocalDraft = url.isNotEmpty;
      _draftSavedAtLabel = savedLabel;
    });
  }

  void _onDraftFieldChanged() {
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    if (_step != _Step.edit || _uploadData == null) return;
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 900), () {
      _saveDraftSilently();
    });
  }

  Future<void> _saveDraftSilently() async {
    if (!mounted || _uploadData == null) return;
    final url = _uploadData!['url']?.toString();
    if (url == null || url.isEmpty) return;
    await _draftStore.save(
      imageUrl: url,
      exifData: _exifMap(),
      title: _title.text,
      caption: _caption.text,
      tips: _tips.text,
      location: _location.text,
      lat: _lat.text,
      lng: _lng.text,
      tagType: _tagType,
      tags: _selectedTags.map((e) => Map<String, String>.from(e)).toList(),
    );
    await _refreshDraftFlag();
  }

  @override
  /// 组件销毁前释放资源，避免监听器或控制器泄漏。
  ///
  /// 方法：`dispose`。
  void dispose() {
    _autoSaveDebounce?.cancel();
    _title.removeListener(_onDraftFieldChanged);
    _caption.removeListener(_onDraftFieldChanged);
    _tips.removeListener(_onDraftFieldChanged);
    _location.removeListener(_onDraftFieldChanged);
    _lat.removeListener(_onDraftFieldChanged);
    _lng.removeListener(_onDraftFieldChanged);
    _tagsInput.removeListener(_onDraftFieldChanged);
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
        _lastUploadError = null;
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
        _lastUploadError = null;
      });
      await _saveDraftSilently();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      setState(() {
        _step = _Step.select;
        _lastUploadError = e.message;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      setState(() {
        _step = _Step.select;
        _lastUploadError = '$e';
      });
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
    _scheduleAutoSave();
  }

  Future<({String copy, List<Map<String, String>> tags})> _requestAiAssist() async {
    final auth = context.read<AuthNotifier>();
    return auth.api.aiPublishAssist(
      title: _title.text.trim(),
      description: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
      locationName: _location.text.trim().isEmpty ? null : _location.text.trim(),
      exifData: _exifMap(),
    );
  }

  Future<void> _applyAiTagSuggestion() async {
    if (_selectedTags.length >= 12) return;
    try {
      final ai = await _requestAiAssist();
      for (final tag in ai.tags) {
        if (_selectedTags.length >= 12) break;
        final name = (tag['name'] ?? '').trim();
        if (name.isEmpty) continue;
        final exists = _selectedTags.any((e) => e['name'] == name);
        if (exists) continue;
        _selectedTags.add({'name': name, 'type': tag['type'] ?? 'scene'});
      }
      if (mounted) setState(() {});
      _scheduleAutoSave();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _applyAiCopySuggestion() async {
    try {
      final ai = await _requestAiAssist();
      if (!mounted) return;
      setState(() {
        if (ai.copy.isNotEmpty) {
          _caption.text = ai.copy;
        }
        _aiCopyHint = 'AI 文案已生成，可继续手动修改';
      });
      _scheduleAutoSave();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
      final newId = await auth.api.photoPublish(
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
      await _draftStore.clear();
      await AnalyticsService.instance.track(
        name: 'publish_success',
        userId: auth.user?.id,
        properties: <String, dynamic>{'photo_id': newId},
      );
      if (!mounted) return;
      await auth.refreshProfile();
      if (!mounted) return;
      _reset();
      context.push('/photo/$newId');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _publish(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 执行业务流程并返回该流程的处理结果。
  ///
  /// 方法：`_reset`。
  void _reset() {
    _autoSaveDebounce?.cancel();
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
      _lastUploadError = null;
    });
  }

  Future<void> _restoreDraft() async {
    final d = await _draftStore.load();
    if (d == null || !mounted) return;
    final url = d['image_url']?.toString();
    if (url == null || url.isEmpty) return;
    final rawExif = d['exif_data'];
    Map<String, dynamic>? exifMap;
    if (rawExif is Map) {
      exifMap = Map<String, dynamic>.from(rawExif);
    }
    setState(() {
      _uploadData = {'url': url, 'exif': exifMap};
      _title.text = d['title']?.toString() ?? '';
      _caption.text = d['caption']?.toString() ?? '';
      _tips.text = d['tips']?.toString() ?? '';
      _location.text = d['location']?.toString() ?? '';
      _lat.text = d['lat']?.toString() ?? '';
      _lng.text = d['lng']?.toString() ?? '';
      _tagType = d['tag_type']?.toString() ?? 'scene';
      _selectedTags.clear();
      final tr = d['tags'];
      if (tr is List) {
        for (final e in tr) {
          if (e is Map) {
            _selectedTags.add({
              'name': e['name']?.toString() ?? '',
              'type': e['type']?.toString() ?? 'scene',
            });
          }
        }
      }
      _imagePath = null;
      _step = _Step.edit;
      _lastUploadError = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已恢复草稿')));
    }
  }

  Future<void> _discardDraft() async {
    await _draftStore.clear();
    if (mounted) {
      setState(() {
        _hasLocalDraft = false;
        _draftSavedAtLabel = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已丢弃草稿')));
    }
  }

  Future<void> _saveDraft() async {
    if (_uploadData == null) return;
    final url = _uploadData!['url']?.toString();
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先上传图片后再存草稿')));
      return;
    }
    await _draftStore.save(
      imageUrl: url,
      exifData: _exifMap(),
      title: _title.text,
      caption: _caption.text,
      tips: _tips.text,
      location: _location.text,
      lat: _lat.text,
      lng: _lng.text,
      tagType: _tagType,
      tags: _selectedTags.map((e) => Map<String, String>.from(e)).toList(),
    );
    if (mounted) {
      await _refreshDraftFlag();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('草稿已保存')));
    }
  }

  Widget _buildExifCard() {
    final ex = _exifMap() ?? <String, dynamic>{};
    int? isoVal;
    final isoRaw = ex['iso'];
    if (isoRaw is num) {
      isoVal = isoRaw.toInt();
    } else if (isoRaw != null) {
      isoVal = int.tryParse(isoRaw.toString());
    }
    final rows = <(String, String)>[
      ('设备', photoParamRecorded(ex['camera_model']?.toString())),
      ('镜头', photoParamRecorded(ex['lens_model']?.toString())),
      ('焦段', photoParamRecorded(ex['focal_length']?.toString())),
      ('光圈', photoApertureRecorded(ex['aperture']?.toString())),
      ('快门', photoParamRecorded(ex['shutter_speed']?.toString())),
      ('ISO', photoIsoRecorded(isoVal)),
      ('白平衡', photoParamRecorded(ex['white_balance']?.toString())),
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
                      r.$2,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '部分机型或未开启相册/相机权限时，EXIF 可能不完整，与详情页展示一致；属正常现象。',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textMuted.withValues(alpha: 0.95),
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
        _Step.uploading => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('正在上传图片并提取 EXIF，请稍候...'),
              ],
            ),
          ),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _applyAiCopySuggestion,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('AI 帮我写'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _aiCopyHint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
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
                          _scheduleAutoSave();
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _applyAiTagSuggestion,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('AI 智能推荐标签'),
                  ),
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
                              _scheduleAutoSave();
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
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : _saveDraft,
                  child: const Text('存草稿'),
                ),
              ],
            ),
          ),
        _Step.select => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 页面标题
                const Text(
                  '发布作品',
                  style: AppTypography.pageTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '选择一张照片，分享你的拍摄故事',
                  style: AppTypography.secondary,
                ),
                const SizedBox(height: AppSpacing.xhuge),

                // 草稿提示
                if (_hasLocalDraft) ...[
                  Container(
                    padding: AppSpacing.cardPadding,
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: AppShapes.radiusXlAll,
                      border: Border.all(color: AppColors.infoLight.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history, color: AppColors.kleinBlue, size: 20),
                            AppSpacing.horizontalSm,
                            const Text(
                              '检测到未发布的草稿',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                        if (_draftSavedAtLabel != null) ...[
                          AppSpacing.verticalXs,
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              '最近保存：$_draftSavedAtLabel',
                              style: AppTypography.secondarySmall,
                            ),
                          ),
                        ],
                        AppSpacing.verticalMd,
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _busy ? null : _restoreDraft,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.kleinBlue,
                                ),
                                child: const Text('继续编辑'),
                              ),
                            ),
                            AppSpacing.horizontalSm,
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy ? null : _discardDraft,
                                child: const Text('丢弃'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.verticalLg,
                ],

                // 错误提示
                if (_lastUploadError != null) ...[
                  Container(
                    padding: AppSpacing.cardPadding,
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: AppShapes.radiusXlAll,
                      border: Border.all(color: AppColors.errorLighter),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        AppSpacing.horizontalSm,
                        Expanded(
                          child: Text(
                            '上次上传失败：$_lastUploadError',
                            style: AppTypography.secondarySmall.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.verticalLg,
                ],

                // 选择图片区域 - 大卡片设计
                if (_imagePath == null) ...[
                  // 未选择图片时的大卡片
                  _buildSelectPhotoCard(
                    icon: Icons.photo_library_rounded,
                    title: '从相册选择',
                    subtitle: '选择已有的照片上传',
                    color: AppColors.kleinBlue,
                    onTap: _busy ? null : () => _pick(ImageSource.gallery),
                  ),
                  AppSpacing.verticalMd,
                  _buildSelectPhotoCard(
                    icon: Icons.camera_alt_rounded,
                    title: '拍照',
                    subtitle: '直接拍摄新照片',
                    color: AppColors.champagneGold,
                    onTap: _busy ? null : () => _pick(ImageSource.camera),
                  ),
                ] else ...[
                  // 已选择图片的预览卡片
                  _buildSelectedImagePreview(),
                  AppSpacing.verticalLg,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.refresh),
                          label: const Text('重新选择'),
                        ),
                      ),
                    ],
                  ),
                ],

                AppSpacing.verticalXxl,

                // 上传按钮
                FilledButton(
                  onPressed: (_busy || _imagePath == null) ? null : _upload,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.kleinBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppShapes.radiusMdAll,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload_outlined),
                      AppSpacing.horizontalSm,
                      Text(
                        _busy ? '上传中...' : '上传并填写信息',
                        style: AppTypography.button,
                      ),
                    ],
                  ),
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
/// 构建图片选择卡片
Widget _buildSelectPhotoCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  VoidCallback? onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppShapes.radiusXxlAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppShapes.radiusXxlAll,
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: color,
              ),
            ),
            AppSpacing.verticalMd,
            Text(
              title,
              style: AppTypography.cardTitle.copyWith(color: color),
            ),
            AppSpacing.verticalXs,
            Text(
              subtitle,
              style: AppTypography.secondarySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

/// 构建已选图片预览卡片
Widget _buildSelectedImagePreview() {
  return Container(
    decoration: BoxDecoration(
      borderRadius: AppShapes.radiusXxlAll,
      boxShadow: AppShapes.elevatedShadow,
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            color: AppColors.placeholder,
            child: const Center(
              child: Icon(
                Icons.image,
                size: 64,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: AppColors.cardWhite,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: AppShapes.radiusSmAll,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              AppSpacing.horizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '图片已选择',
                      style: AppTypography.body,
                    ),
                    Text(
                      '点击下方按钮继续编辑',
                      style: AppTypography.secondarySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

enum _Step { select, uploading, edit }
