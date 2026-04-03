// 文件说明：路由层代码，负责页面路由定义与跳转守卫。
// 维护建议：修改行为时同步更新注释，保证文档与实现一致。

// 路由模块：集中定义页面跳转规则、重定向逻辑与路由守卫。
//
// 说明：该文件已补充中文注释，便于后续维护与交接。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tongjing/providers/auth_provider.dart';
import 'package:tongjing/screens/add_spot/add_spot_screen.dart';
import 'package:tongjing/screens/author_profile/author_profile_screen.dart';
import 'package:tongjing/screens/challenges/challenges_screen.dart';
import 'package:tongjing/screens/edit_profile/edit_profile_screen.dart';
import 'package:tongjing/screens/favorites/favorites_screen.dart';
import 'package:tongjing/screens/home/home_screen.dart';
import 'package:tongjing/screens/login/login_screen.dart';
import 'package:tongjing/screens/map/location_photos_screen.dart';
import 'package:tongjing/screens/map/map_screen.dart' show MapOpenArgs, MapScreen;
import 'package:tongjing/screens/my_equipment/my_equipment_screen.dart';
import 'package:tongjing/screens/my_plans/my_plans_screen.dart';
import 'package:tongjing/screens/my_spots/my_spots_screen.dart';
import 'package:tongjing/screens/my_works/my_works_screen.dart';
import 'package:tongjing/router/photo_gallery_extra.dart';
import 'package:tongjing/screens/photo_detail/photo_detail_screen.dart';
import 'package:tongjing/screens/plan/plan_screen.dart';
import 'package:tongjing/screens/profile/my_follow_list_screen.dart';
import 'package:tongjing/screens/profile/my_interaction_lists_screen.dart';
import 'package:tongjing/screens/profile/profile_screen.dart';
import 'package:tongjing/screens/publish/publish_screen.dart';
import 'package:tongjing/screens/settings/settings_screen.dart';
import 'package:tongjing/screens/settings/notifications_settings_screen.dart';
import 'package:tongjing/screens/settings/app_preferences_screen.dart';
import 'package:tongjing/screens/settings/device_sessions_screen.dart';
import 'package:tongjing/screens/settings/login_history_screen.dart';
import 'package:tongjing/screens/shell/main_shell.dart';
import 'package:tongjing/screens/static/about_screen.dart';
import 'package:tongjing/screens/static/account_security_screen.dart';
import 'package:tongjing/screens/static/privacy_screen.dart';
import 'package:tongjing/screens/static/terms_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 带过渡动画的页面：淡入 + 轻微上滑
CustomTransitionPage<void> _fadeSlidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      );
    },
  );
}

GoRouter createAppRouter(AuthNotifier auth) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: auth,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) {
                  final extra = state.extra;
                  return MapScreen(
                    initialTarget: extra is MapOpenArgs ? extra : null,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/publish',
                builder: (context, state) => const PublishScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/photo/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final ex = state.extra;
          List<int>? galleryIds;
          var galleryIx = 0;
          if (ex is PhotoGalleryExtra) {
            final raw = dedupePhotoIdsInOrder(ex.photoIds);
            if (raw.length > 1) {
              galleryIds = raw;
              galleryIx = ex.initialIndex.clamp(0, galleryIds.length - 1);
              if (galleryIds[galleryIx] != id) {
                final found = galleryIds.indexOf(id);
                if (found >= 0) galleryIx = found;
              }
            }
          }
          return _fadeSlidePage(
            state,
            PhotoDetailScreen(
              photoId: id,
              galleryPhotoIds: galleryIds,
              galleryInitialIndex: galleryIx,
            ),
          );
        },
      ),
      GoRoute(
        path: '/map/location-photos',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final ex = state.extra;
          final args = ex is MapLocationPhotosArgs
              ? ex
              : const MapLocationPhotosArgs(locationName: '该地点作品', photos: []);
          return _fadeSlidePage(
            state,
            MapLocationPhotosScreen(args: args),
          );
        },
      ),
      GoRoute(
        path: '/user/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return _fadeSlidePage(state, AuthorProfileScreen(userId: id));
        },
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const SettingsScreen()),
      ),
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const EditProfileScreen()),
      ),
      GoRoute(
        path: '/my-equipment',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const MyEquipmentScreen()),
      ),
      GoRoute(
        path: '/privacy',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const PrivacyScreen()),
      ),
      GoRoute(
        path: '/terms',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const TermsScreen()),
      ),
      GoRoute(
        path: '/account-security',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const AccountSecurityScreen()),
      ),
      GoRoute(
        path: '/about',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _fadeSlidePage(state, const AboutScreen()),
      ),
      GoRoute(
        path: '/settings/notifications',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const NotificationsSettingsScreen()),
      ),
      GoRoute(
        path: '/settings/preferences',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const AppPreferencesScreen()),
      ),
      GoRoute(
        path: '/settings/device-sessions',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const DeviceSessionsScreen()),
      ),
      GoRoute(
        path: '/settings/login-history',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const LoginHistoryScreen()),
      ),
      GoRoute(
        path: '/favorites',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const FavoritesScreen()),
      ),
      GoRoute(
        path: '/my-works',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const MyWorksScreen()),
      ),
      GoRoute(
        path: '/my-stats/received-likes',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const MyReceivedWorksScreen(sort: 'likes')),
      ),
      GoRoute(
        path: '/my-stats/received-favorites',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const MyReceivedWorksScreen(sort: 'favorites')),
      ),
      GoRoute(
        path: '/my-liked-photos',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const MyLikedPhotosScreen()),
      ),
      GoRoute(
        path: '/my-followers',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const MyFollowListScreen(showFollowing: false)),
      ),
      GoRoute(
        path: '/my-following',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const MyFollowListScreen(showFollowing: true)),
      ),
      GoRoute(
        path: '/my-spots',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const MySpotsScreen()),
      ),
      GoRoute(
        path: '/add-spot',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const AddSpotScreen()),
      ),
      GoRoute(
        path: '/my-plans',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadeSlidePage(state, const MyPlansScreen()),
      ),
      GoRoute(
        path: '/challenges',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.uri.queryParameters['id'] ?? '');
          return _fadeSlidePage(state, ChallengesScreen(challengeId: id));
        },
      ),
    ],
  );
}
