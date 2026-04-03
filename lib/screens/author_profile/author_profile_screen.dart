import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/models/user_model.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/router/photo_gallery_extra.dart';
import 'package:tongjing/services/analytics_service.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/services/photo_state_sync_bus.dart';
import 'package:tongjing/theme/app_colors.dart';
import 'package:tongjing/utils/remote_image.dart';
import 'package:tongjing/widgets/gear_card.dart';

/// 他人公开主页：布局与「我的」一致（克莱因蓝头图卡片 + 分区列表），便于认知统一。
class AuthorProfileScreen extends StatefulWidget {
  const AuthorProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  State<AuthorProfileScreen> createState() => _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends State<AuthorProfileScreen> {
  final _syncBus = PhotoStateSyncBus.instance;
  UserModel? _user;
  List<PhotoListItem> _photos = [];
  List<Map<String, dynamic>> _gear = [];
  bool _loading = true;
  String? _error;
  static const int _photoLimit = 60;

  @override
  void initState() {
    super.initState();
    _syncBus.addListener(_onPhotoStateSync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _syncBus.removeListener(_onPhotoStateSync);
    super.dispose();
  }

  void _onPhotoStateSync() {
    final e = _syncBus.lastEvent;
    if (!mounted || e == null) return;
    final idx = _photos.indexWhere((x) => x.id == e.photoId);
    if (idx < 0) return;
    final before = _photos[idx];
    final next = before.copyWith(
      isLiked: e.isLiked ?? before.isLiked,
      likesCount: e.likesCount ?? before.likesCount,
      isFavorited: e.isFavorited ?? before.isFavorited,
      favoritesCount: e.favoritesCount ?? before.favoritesCount,
    );
    setState(() => _photos[idx] = next);
  }

  Future<void> _load({bool reset = false}) async {
    if (widget.userId <= 0) {
      setState(() {
        _loading = false;
        _error = '无效用户';
      });
      return;
    }
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _photos = [];
        _gear = [];
      });
    }
    final auth = context.read<AuthNotifier>();
    try {
      final u = await auth.api.usersPublic(widget.userId);
      if (!mounted) return;
      final first = await auth.api.usersPublicPhotos(widget.userId, page: 1, limit: _photoLimit);
      if (!mounted) return;
      List<Map<String, dynamic>> gear = [];
      try {
        gear = await auth.api.equipmentForUser(widget.userId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _user = u;
        _photos = first.photos;
        _gear = gear;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openPhotoInGallery(PhotoListItem p) async {
    final ids = dedupePhotoIdsInOrder(_photos.map((e) => e.id));
    final ix = ids.indexOf(p.id);
    final router = GoRouter.of(context);
    final dynamic r = ids.length > 1
        ? await router.push(
            '/photo/${p.id}',
            extra: PhotoGalleryExtra(
              photoIds: ids,
              initialIndex: ix >= 0 ? ix : 0,
            ),
          )
        : await router.push('/photo/${p.id}');
    if (!mounted) return;
    if (r == true) await _load(reset: true);
  }

  Future<void> _toggleFollow() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      if (mounted) context.push('/login');
      return;
    }
    try {
      final nowFollowing = await auth.api.usersFollowToggle(widget.userId);
      await AnalyticsService.instance.track(
        name: nowFollowing ? 'follow_on' : 'follow_off',
        userId: auth.user?.id,
        properties: <String, dynamic>{'target_user_id': widget.userId},
      );
      if (!mounted) return;
      await auth.refreshProfile();
      if (!mounted) return;
      final u = await auth.api.usersPublic(widget.userId);
      if (mounted) setState(() => _user = u);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _headerStat(String label, int v) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$v',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFDDE3F6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meId = context.select<AuthNotifier, int?>(
        (a) => a.isAuthenticated ? a.user?.id : null);
    final isMe = meId != null && meId == widget.userId;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading && _user == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.kleinBlue))
          : _error != null && _user == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        const Text(
                          '加载失败',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => _load(reset: true),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.kleinBlue),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: RefreshIndicator(
                    color: AppColors.kleinBlue,
                    onRefresh: () => _load(reset: true),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF0E2A7B), AppColors.kleinBlue],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.all(Radius.circular(16)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () => context.pop(),
                                            icon: const Icon(
                                              Icons.arrow_back_rounded,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const Spacer(),
                                        ],
                                      ),
                                      _AuthorProfileAvatar(user: _user!),
                                      const SizedBox(height: 12),
                                      Text(
                                        _user?.username ?? '用户',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _user?.bio ?? '暂无简介',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFFDDE3F6),
                                          fontSize: 14,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        alignment: WrapAlignment.spaceEvenly,
                                        runSpacing: 10,
                                        spacing: 4,
                                        children: [
                                          _headerStat('作品', _user?.photosCount ?? _photos.length),
                                          _headerStat('粉丝', _user?.followersCount ?? 0),
                                          _headerStat('关注', _user?.followingCount ?? 0),
                                        ],
                                      ),
                                      if (!isMe) ...[
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 46,
                                          child: FilledButton(
                                            onPressed: _toggleFollow,
                                            style: FilledButton.styleFrom(
                                              backgroundColor: _user?.isFollowing == true
                                                  ? const Color(0xFFE8ECF5)
                                                  : Colors.white,
                                              foregroundColor: _user?.isFollowing == true
                                                  ? AppColors.textSecondary
                                                  : AppColors.kleinBlue,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              _user?.isFollowing == true ? '已关注' : '关注',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(height: 14),
                                  Material(
                                    color: const Color(0xFFE8F0FE),
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      onTap: () => context.go('/profile'),
                                      borderRadius: BorderRadius.circular(16),
                                      child: const Padding(
                                        padding: EdgeInsets.all(14),
                                        child: Row(
                                          children: [
                                            Icon(Icons.info_outline,
                                                color: AppColors.kleinBlue, size: 22),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                '这是你的账号。编辑资料与防潮箱请前往「我的」。',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textSecondary,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '去我的',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.kleinBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '防潮箱',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 96,
                                  child: _gear.isEmpty
                                      ? Center(
                                          child: Text(
                                            '暂未展示装备',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textMuted.withValues(alpha: 0.9),
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _gear.length,
                                          itemBuilder: (context, i) {
                                            final e = _gear[i];
                                            final brand = e['brand']?.toString() ?? '';
                                            final model = e['model']?.toString() ?? '';
                                            final title = '$brand $model'.trim();
                                            final type = e['type']?.toString() ?? '';
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                  right: i == _gear.length - 1 ? 0 : 8),
                                              child: GearCard(
                                                title: title.isEmpty ? '器材' : title,
                                                type: type,
                                              ),
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(height: 20),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '公开作品',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '点进作品后左右滑动可连续浏览',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        if (_photos.isEmpty && !_loading)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 36),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: const Text(
                                  '暂无公开作品',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(12, 0, 12, 16 + bottomInset),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                                childAspectRatio: 1,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final p = _photos[i];
                                  return GestureDetector(
                                    onTap: () => _openPhotoInGallery(p),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: CachedNetworkImage(
                                        imageUrl: p.imageUrl,
                                        fit: BoxFit.cover,
                                        httpHeaders: kRemoteImageHttpHeaders,
                                        placeholder: (context, progress) => Container(
                                          color: AppColors.borderLight,
                                          child: const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.kleinBlue,
                                              ),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: AppColors.borderLight,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
                                            color: AppColors.textMuted,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: _photos.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _AuthorProfileAvatar extends StatelessWidget {
  const _AuthorProfileAvatar({required this.user});

  final UserModel user;

  static String _initial(String username) {
    if (username.isEmpty) return '?';
    return String.fromCharCode(username.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final url = resolveAvatarUrl(user.avatarUrl, user.username);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        httpHeaders: kRemoteImageHttpHeaders,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        placeholder: (context, progress) => Container(
          width: 84,
          height: 84,
          color: Colors.white24,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 42,
          backgroundColor: Colors.white24,
          child: Text(
            _initial(user.username),
            style: const TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
