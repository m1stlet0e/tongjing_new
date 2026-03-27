// 文件说明：页面层代码，负责 UI 构建、交互处理与页面状态展示。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 页面模块：`map_screen` 页面，负责对应业务场景的 UI 组织、交互处理与状态展示。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/theme/app_colors.dart';

/// `MapScreen`：页面组件，负责构建界面布局并响应用户操作。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// `_MapScreenState`：核心类型定义，承载该模块的主要职责。
///
/// 主要用于统一该模块的核心能力与数据结构边界。
class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _search = TextEditingController();
  LatLng _center = const LatLng(31.2304, 121.4737);
  List<PhotoListItem> _markers = [];
  List<Map<String, dynamic>> _popular = [];
  bool _loading = true;
  String? _error;
  String _radiusKm = '50';
  static const _mockImage =
      'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1200&q=80';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  /// 组件初始化阶段执行一次，用于准备首屏数据与监听器。
  ///
  /// 方法：`initState`。
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _locate() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    final pos = await Geolocator.getCurrentPosition();
    final ll = LatLng(pos.latitude, pos.longitude);
    setState(() => _center = ll);
    _mapController.move(ll, 13);
    _load();
  }

  Future<void> _load() async {
    if (AppConfig.useMockData) {
      setState(() {
        _loading = false;
        _error = null;
        _markers = _mockMarkers();
        _popular = _mockPopular();
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthNotifier>().api;
      final photos = await api.mapPhotos(
        lat: _center.latitude,
        lng: _center.longitude,
        radiusKm: _radiusKm,
      );
      final pop = await api.mapPopularSpots();
      setState(() {
        _markers = photos;
        _popular = pop;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : '地图数据加载失败';
        _markers = [];
        _popular = [];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  /// 构建当前组件的 Widget 树，并根据状态输出对应界面。
  ///
  /// 方法：`build`。
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filteredMarkers = _markers.where((p) {
      if (query.isEmpty) return true;
      final title = (p.title ?? '').toLowerCase();
      final location = (p.locationName ?? '').toLowerCase();
      return title.contains(query) || location.contains(query);
    }).toList();
    final filteredPopular = _popular.where((s) {
      if (query.isEmpty) return true;
      final name = (s['location_name']?.toString() ?? '').toLowerCase();
      return name.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '机位地图',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.kleinBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '搜索地标或机位',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'AI 预测：今日 17:45 - 18:20 光线最佳，适合城市夜景机位',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.kleinBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['5', '20', '50'].map((r) {
                      return ChoiceChip(
                        label: Text('${r}km'),
                        selected: _radiusKm == r,
                        onSelected: (_) {
                          setState(() => _radiusKm = r);
                          _load();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 12,
                    onPositionChanged: (pos, _) {
                      _center = pos.center;
                    },
                    onMapEvent: (e) {
                      if (e is MapEventMoveEnd) {
                        _load();
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tongjing.tongjing',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final p in filteredMarkers)
                          if (p.latitude != null && p.longitude != null)
                            Marker(
                              point: LatLng(p.latitude!, p.longitude!),
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () => context.push('/photo/${p.id}'),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: p.imageUrl,
                                    fit: BoxFit.cover,
                                    width: 44,
                                    height: 44,
                                    errorWidget: (_, __, ___) =>
                                        Container(color: AppColors.kleinBlue),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Text(
                            '热门机位',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          if (_loading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          IconButton(
                            onPressed: _locate,
                            icon: const Icon(Icons.my_location,
                                color: AppColors.kleinBlue),
                          ),
                          IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.redAccent)),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: filteredPopular.length,
                        itemBuilder: (context, i) {
                          final s = filteredPopular[i];
                          final name =
                              s['location_name']?.toString() ?? '未知地点';
                          final cnt =
                              (s['photo_count'] as num?)?.toInt() ?? 0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.place,
                                  color: AppColors.kleinBlue),
                              title: Text(name),
                              subtitle: Text('$cnt 张作品'),
                              onTap: () {
                                final lat = (s['latitude'] as num?)?.toDouble();
                                final lng = (s['longitude'] as num?)?.toDouble();
                                if (lat == null || lng == null) return;
                                final ll = LatLng(lat, lng);
                                setState(() => _center = ll);
                                _mapController.move(ll, 14);
                                _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PhotoListItem> _mockMarkers() {
    return [
      PhotoListItem(
        id: 99001,
        imageUrl: _mockImage,
        title: '外滩机位示例',
        locationName: '外滩观景台',
        latitude: 31.2400,
        longitude: 121.4900,
        cameraModel: 'Sony A7M4',
        likesCount: 120,
      ),
      PhotoListItem(
        id: 99002,
        imageUrl:
            'https://images.unsplash.com/photo-1514565131-fce0801e5785?auto=format&fit=crop&w=1200&q=80',
        title: '陆家嘴夜景示例',
        locationName: '陆家嘴滨江',
        latitude: 31.2350,
        longitude: 121.5070,
        cameraModel: 'Canon R6',
        likesCount: 88,
      ),
      PhotoListItem(
        id: 99003,
        imageUrl:
            'https://images.unsplash.com/photo-1461716834815-55d4f42a5d05?auto=format&fit=crop&w=1200&q=80',
        title: '武康路街拍示例',
        locationName: '武康路',
        latitude: 31.2044,
        longitude: 121.4338,
        cameraModel: 'Fujifilm X-T5',
        likesCount: 66,
      ),
    ];
  }

  List<Map<String, dynamic>> _mockPopular() {
    return [
      {
        'location_name': '外滩观景台',
        'latitude': 31.2400,
        'longitude': 121.4900,
        'photo_count': 86,
      },
      {
        'location_name': '陆家嘴滨江',
        'latitude': 31.2350,
        'longitude': 121.5070,
        'photo_count': 59,
      },
      {
        'location_name': '武康路',
        'latitude': 31.2044,
        'longitude': 121.4338,
        'photo_count': 42,
      },
    ];
  }
}
