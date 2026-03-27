import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tongjing/config/app_config.dart';
import 'package:tongjing/models/photo_models.dart';
import 'package:tongjing/models/user_model.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/services/api_service.dart';
import 'package:tongjing/theme/app_colors.dart';

/// 他人公开主页：视觉与「我的」区分（暖色顶栏、文案「摄影师主页」），仅展示公开信息与作品网格。
class AuthorProfileScreen extends StatefulWidget {
  const AuthorProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  State<AuthorProfileScreen> createState() => _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends State<AuthorProfileScreen> {
  UserModel? _user;
  List<PhotoListItem> _photos = [];
  bool _loading = true;
  String? _error;
  static const int _photoLimit = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (widget.userId <= 0) {
      setState(() {
        _loading = false;
        _error = '无效用户';
      });
      return;
    }
    if (AppConfig.useMockData) {
      setState(() {
        _loading = false;
        _error = null;
        _user = UserModel(
          id: widget.userId,
          username: widget.userId == 88002 ? 'Mock南风' : 'MockCreator',
          bio: '这是本地 Mock 作者主页，连接真实后端后将显示服务器数据。',
          avatarUrl: null,
          photosCount: 6,
          followersCount: 128,
          followingCount: 32,
          isFollowing: false,
        );
        _photos = List.generate(6, (i) {
          return PhotoListItem(
            id: 91000 + i,
            imageUrl:
                'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=600&q=80',
            title: 'Mock 作品 ${i + 1}',
            username: _user!.username,
            userId: widget.userId,
            likesCount: 20 + i,
          );
        });
      });
      return;
    }

    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _photos = [];
      });
    }
    final auth = context.read<AuthNotifier>();
    try {
      final u = await auth.api.usersPublic(widget.userId);
      if (!mounted) return;
      final first = await auth.api.usersPublicPhotos(widget.userId, page: 1, limit: _photoLimit);
      if (!mounted) return;
      setState(() {
        _user = u;
        _photos = first.photos;
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

  Future<void> _toggleFollow() async {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) {
      if (mounted) context.push('/login');
      return;
    }
    try {
      await auth.api.usersFollowToggle(widget.userId);
      if (!mounted) return;
      final u = await auth.api.usersPublic(widget.userId);
      if (mounted) setState(() => _user = u);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final isMe = auth.isAuthenticated && auth.user?.id == widget.userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EF),
      body: _loading && _user == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _user == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(onPressed: () => _load(reset: true), child: const Text('重试')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFC45C26),
                  onRefresh: () => _load(reset: true),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: 168,
                        backgroundColor: const Color(0xFF2D1810),
                        foregroundColor: Colors.white,
                        iconTheme: const IconThemeData(color: Colors.white),
                        flexibleSpace: FlexibleSpaceBar(
                          title: const Text(
                            '摄影师主页',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                            ),
                          ),
                          background: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF4A2C1A), Color(0xFFC45C26), Color(0xFFE8A87C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  '公开资料 · 非个人中心',
                                  style: TextStyle(color: Color(0x66FFFFFF), fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isMe)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.kleinBlue.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: AppColors.kleinBlue),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          '这是你的账号。编辑资料、防潮箱等请前往底部「我的」。',
                                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context.go('/profile'),
                                        child: const Text('去我的'),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: const Color(0xFFE8D5C4),
                                    backgroundImage: _user?.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
                                        ? CachedNetworkImageProvider(_user!.avatarUrl!)
                                        : null,
                                    child: _user?.avatarUrl == null || _user!.avatarUrl!.isEmpty
                                        ? Text(
                                            (_user?.username ?? '').isNotEmpty
                                                ? _user!.username.substring(0, 1).toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              color: Color(0xFF5C3D2E),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _user?.username ?? '用户',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF2D1810),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0x33C45C26),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: const Color(0x88C45C26)),
                                              ),
                                              child: const Text(
                                                'Ta 的主页',
                                                style: TextStyle(fontSize: 11, color: Color(0xFFC45C26)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _user?.bio ?? '暂无简介',
                                          style: const TextStyle(color: AppColors.textSecondary, height: 1.35),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _miniStat('作品', _user?.photosCount ?? _photos.length),
                                            const SizedBox(width: 20),
                                            _miniStat('粉丝', _user?.followersCount ?? 0),
                                            const SizedBox(width: 20),
                                            _miniStat('关注', _user?.followingCount ?? 0),
                                          ],
                                        ),
                                        if (!isMe) ...[
                                          const SizedBox(height: 14),
                                          SizedBox(
                                            width: double.infinity,
                                            child: FilledButton(
                                              onPressed: _toggleFollow,
                                              style: FilledButton.styleFrom(
                                                backgroundColor: (_user?.isFollowing == true)
                                                    ? AppColors.textMuted
                                                    : const Color(0xFFC45C26),
                                              ),
                                              child: Text(_user?.isFollowing == true ? '已关注' : '+ 关注'),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                '公开作品',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF2D1810)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_photos.isEmpty && !_loading)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: Text('暂无公开作品')),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
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
                                  onTap: () => context.push('/photo/${p.id}'),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CachedNetworkImage(imageUrl: p.imageUrl, fit: BoxFit.cover),
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
    );
  }

  static Widget _miniStat(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2D1810))),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}
