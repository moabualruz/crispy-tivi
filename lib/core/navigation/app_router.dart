import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_routes.dart';
export 'app_routes.dart';
import 'crispy_fade_transition_page.dart';
import '../widgets/responsive_layout.dart';
import '../../config/settings_notifier.dart';
import '../../features/profiles/data/profile_service.dart';

import '../../features/dvr/presentation/screens/cloud_browser_screen.dart';
import '../../features/dvr/presentation/screens/recordings_screen.dart';
import '../../features/epg/presentation/screens/epg_timeline_screen.dart';
import '../../features/favorites/presentation/screens/history_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/vod/presentation/screens/series_browser_screen.dart';
import '../../features/iptv/presentation/screens/channel_list_screen.dart';
import '../../features/media_servers/shared/presentation/screens/media_server_browser_screen.dart';
import '../../features/media_servers/jellyfin/presentation/screens/jellyfin_home_screen.dart';
import '../../features/media_servers/jellyfin/presentation/screens/jellyfin_library_screen.dart';
import '../../features/media_servers/jellyfin/presentation/screens/jellyfin_login_screen.dart';
import '../../features/media_servers/jellyfin/presentation/screens/jellyfin_series_screen.dart';
import '../../features/media_servers/emby/presentation/screens/emby_home_screen.dart';
import '../../features/media_servers/emby/presentation/screens/emby_library_screen.dart';
import '../../features/media_servers/emby/presentation/screens/emby_login_screen.dart';
import '../../features/media_servers/emby/presentation/screens/emby_series_screen.dart';
import '../../features/media_servers/plex/presentation/screens/plex_home_screen.dart';
import '../../features/media_servers/plex/presentation/screens/plex_library_screen.dart';
import '../../features/media_servers/plex/presentation/screens/plex_login_screen.dart';
import '../../features/multiview/presentation/screens/multi_view_screen.dart';
import '../../features/profiles/presentation/screens/profile_management_screen.dart';
import '../../features/profiles/presentation/screens/profile_selection_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/vod/domain/entities/vod_item.dart';
import '../../features/vod/presentation/screens/series_detail_screen.dart';
import '../../features/vod/presentation/screens/vod_browser_screen.dart';
import '../../features/vod/presentation/screens/vod_details_screen.dart';
import '../../features/media_servers/shared/presentation/screens/media_item_details_screen.dart';
import '../domain/entities/media_item.dart';
import '../domain/media_source.dart';
import '../../features/player/presentation/providers/player_providers.dart';
import 'app_shell.dart';

/// Fallback screen shown when required route data is missing.
///
/// Used as an error boundary for routes that require [extra]
/// data (e.g., VodDetails, SeriesDetail, MediaServerDetails).
/// In debug mode the [title] is shown; in release mode a
/// generic "Not found" message is displayed so internal route
/// names are not leaked.
class _FallbackScreen extends StatelessWidget {
  const _FallbackScreen(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final displayTitle = kDebugMode ? title : 'Page not found';
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(displayTitle, style: textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}

// ── Media-server route builder helpers (AS-13) ───────────────────────────────
//
// Jellyfin and Emby share the same three-route pattern:
//   - /server/login  → LoginScreen
//   - /server/home   → HomeScreen
//   - /server/library/:parentId → LibraryScreen(parentId, title)
//
// The widget types differ per server so a generic parameterization
// would require a factory abstraction with more complexity than the
// duplication itself. Instead the shared pattern is documented here
// and the library-route builder is extracted as a typed helper below.
// Plex has extra sub-routes (/children/:itemId) and a different ID
// parameter name, so it stays separate.

/// Builds a `/server/library/:parentId` [GoRoute] with a title query parameter.
///
/// [path] — the full route path (e.g., `/jellyfin/library/:parentId`).
/// [paramName] — the path parameter name (`parentId` or `libraryId`).
/// [builder] — factory that constructs the screen from id and title.
GoRoute _buildLibraryRoute(
  String path, {
  required String paramName,
  required Widget Function(String id, String title) builder,
}) {
  return GoRoute(
    path: path,
    builder: (context, state) {
      final id = state.pathParameters[paramName] ?? '';
      final title = state.uri.queryParameters['title'] ?? 'Library';
      return builder(id, title);
    },
  );
}

/// Builds an adaptive page based on screen layout class.
///
/// - TV / large (≥ 1200 dp): [NoTransitionPage] — instant switch,
///   D-pad users expect zero latency.
/// - Compact / medium / expanded: [CrispyFadeTransitionPage] — 300 ms
///   cross-fade gives touch/pointer users a visual cue.
Page<T> _adaptivePage<T>(BuildContext context, LocalKey key, Widget child) {
  if (context.isLarge) {
    return NoTransitionPage<T>(key: key, child: child);
  }
  return CrispyFadeTransitionPage<T>(key: key, child: child);
}

/// All named routes in CrispyTivi.

// The GoRouter configuration.
//
// IMPORTANT: Do NOT use ref.watch() for profileServiceProvider here.
// Watching causes the entire GoRouter to be recreated on every
// profile state change, resetting navigation to initialLocation.
/// Notifier used to re-evaluate GoRouter redirects when
/// async provider state changes (e.g. profiles finish loading).
class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects when profile or settings state changes
  // (e.g. loading → data). This does NOT recreate the router.
  final profileRefresh = _RouterRefreshNotifier();
  final settingsRefresh = _RouterRefreshNotifier();
  ref.onDispose(() {
    profileRefresh.dispose();
    settingsRefresh.dispose();
  });
  ref.listen(profileServiceProvider, (_, _) => profileRefresh.refresh());
  ref.listen(settingsNotifierProvider, (_, _) => settingsRefresh.refresh());

  return GoRouter(
    debugLogDiagnostics: kDebugMode,
    refreshListenable: Listenable.merge([profileRefresh, settingsRefresh]),
    redirect: (context, state) {
      // Read profile state on-demand (not watch) so the router
      // is not rebuilt when profile changes.
      final profileAsync = ref.read(profileServiceProvider);
      if (profileAsync.isLoading) return null;
      // BUG-10: errors must redirect to profiles, not pass through
      if (profileAsync.hasError) return AppRoutes.profiles;

      // Wait for settings to finish loading before redirecting
      final settingsAsync = ref.read(settingsNotifierProvider);
      if (settingsAsync.isLoading) return null;

      final path = state.matchedLocation;

      // ── Auto-skip profile selection for single profile ──
      // When navigating to /profiles (initial location on app
      // start), skip entirely if only one profile exists without
      // PIN. Explicit navigation from Settings passes
      // extra: {'explicit': true} to bypass this.
      if (path == AppRoutes.profiles) {
        // BUG-03: safe type check instead of unsafe cast
        final isExplicit =
            state.extra is Map<String, dynamic> &&
            (state.extra as Map<String, dynamic>)['explicit'] == true;
        final profiles = profileAsync.value?.profiles ?? [];
        if (!isExplicit && profiles.length == 1 && !profiles.first.hasPIN) {
          // The single profile is already active (ProfileService.build
          // sets activeProfileId to profiles.first.id). Just redirect
          // to the user's preferred default screen — no state mutation
          // inside the redirect to avoid refreshListenable re-entrancy.
          final defaultScreen = settingsAsync.value?.defaultScreen ?? 'home';
          return defaultScreen == 'live_tv' ? AppRoutes.tv : AppRoutes.home;
        }
      }

      // Navigation guards for role-based access
      final profile = profileAsync.value?.activeProfile;
      if (profile != null) {
        // Admin-only routes
        if (path == AppRoutes.profileManagement && !profile.isAdmin) {
          return AppRoutes.home;
        }

        // Settings access (restricted profiles blocked)
        if (path == AppRoutes.settings && !profile.canAccessSettings) {
          return AppRoutes.home;
        }
      }

      return null;
    },
    initialLocation: AppRoutes.profiles,
    routes: [
      // ── Shell wraps the tabbed destinations ──
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder:
                (context, state) =>
                    _adaptivePage(context, state.pageKey, const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.tv,
            pageBuilder:
                (context, state) => _adaptivePage(
                  context,
                  state.pageKey,
                  const ChannelListScreen(),
                ),
          ),
          GoRoute(
            path: AppRoutes.epg,
            pageBuilder:
                (context, state) => _adaptivePage(
                  context,
                  state.pageKey,
                  const EpgTimelineScreen(),
                ),
          ),
          GoRoute(
            path: AppRoutes.vod,
            pageBuilder:
                (context, state) =>
                    _adaptivePage(context, state.pageKey, VodBrowserScreen()),
          ),
          GoRoute(
            path: AppRoutes.series,
            pageBuilder:
                (context, state) => _adaptivePage(
                  context,
                  state.pageKey,
                  const SeriesBrowserScreen(),
                ),
          ),
          GoRoute(
            path: AppRoutes.dvr,
            pageBuilder:
                (context, state) => _adaptivePage(
                  context,
                  state.pageKey,
                  const RecordingsScreen(),
                ),
          ),
          GoRoute(
            path: AppRoutes.favorites,
            pageBuilder:
                (context, state) => _adaptivePage(
                  context,
                  state.pageKey,
                  const HistoryScreen(),
                ),
          ),
          GoRoute(
            path: AppRoutes.customSearch,
            pageBuilder:
                (context, state) =>
                    _adaptivePage(context, state.pageKey, const SearchScreen()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder:
                (context, state) => _adaptivePage(
                  context,
                  state.pageKey,
                  const SettingsScreen(),
                ),
          ),

          // ── Sub-pages inside shell (BUG-002 fix) ──
          // These routes keep the nav rail visible so
          // users can navigate away and the Escape key
          // handler in AppShell stays active (BUG-004).
          GoRoute(
            path: AppRoutes.mediaServers,
            builder: (context, state) => const MediaServerBrowserScreen(),
          ),
          GoRoute(
            path: AppRoutes.mediaServerDetails,
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              if (extra == null ||
                  extra['item'] is! MediaItem ||
                  extra['serverType'] is! MediaServerType) {
                return const _FallbackScreen('Media Server Details');
              }
              final item = extra['item'] as MediaItem;
              final serverType = extra['serverType'] as MediaServerType;
              final heroTag = extra['heroTag'] as String?;
              final getStreamUrl =
                  extra['getStreamUrl'] as Future<String> Function(String)?;
              return MediaItemDetailsScreen(
                item: item,
                serverType: serverType,
                getStreamUrl: getStreamUrl,
                heroTag: heroTag,
              );
            },
          ),
          // ── Jellyfin ──────────────────────────────────────────
          GoRoute(
            path: AppRoutes.jellyfinLogin,
            builder: (context, state) => const JellyfinLoginScreen(),
          ),
          GoRoute(
            path: '/jellyfin/home',
            builder: (context, state) => const JellyfinHomeScreen(),
          ),
          _buildLibraryRoute(
            '/jellyfin/library/:parentId',
            paramName: 'parentId',
            builder:
                (id, title) =>
                    JellyfinLibraryScreen(parentId: id, title: title),
          ),
          // JF-FE-12: Series navigation (seasons + episodes).
          _buildLibraryRoute(
            '${AppRoutes.jellyfinSeriesBase}/:seriesId',
            paramName: 'seriesId',
            builder:
                (id, title) => JellyfinSeriesScreen(seriesId: id, title: title),
          ),

          // ── Emby ──────────────────────────────────────────────
          GoRoute(
            path: AppRoutes.embyLogin,
            builder: (context, state) => const EmbyLoginScreen(),
          ),
          GoRoute(
            path: '/emby/home',
            builder: (context, state) => const EmbyHomeScreen(),
          ),
          _buildLibraryRoute(
            '/emby/library/:parentId',
            paramName: 'parentId',
            builder:
                (id, title) => EmbyLibraryScreen(parentId: id, title: title),
          ),
          // EB-FE-11: Series navigation (seasons + episodes).
          _buildLibraryRoute(
            '${AppRoutes.embySeriesBase}/:seriesId',
            paramName: 'seriesId',
            builder:
                (id, title) => EmbySeriesScreen(seriesId: id, title: title),
          ),

          // ── Plex (extra sub-routes: /library/:libraryId and /children/:itemId) ──
          GoRoute(
            path: AppRoutes.plexLogin,
            builder: (context, state) => const PlexLoginScreen(),
          ),
          GoRoute(
            path: '/plex/home',
            builder: (context, state) => const PlexHomeScreen(),
          ),
          _buildLibraryRoute(
            '${AppRoutes.plexLibraryBase}/:libraryId',
            paramName: 'libraryId',
            builder:
                (id, title) => PlexLibraryScreen(libraryId: id, title: title),
          ),
          GoRoute(
            path: '${AppRoutes.plexChildrenBase}/:itemId',
            builder: (context, state) {
              final itemId = state.pathParameters['itemId'] ?? '';
              final title = state.uri.queryParameters['title'] ?? 'Browse';
              return PlexLibraryScreen(
                libraryId: itemId,
                title: title,
                isChildren: true,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.seriesDetail,
            builder: (context, state) {
              final series = state.extra as VodItem?;
              if (series == null) {
                return const _FallbackScreen('Series Detail');
              }
              return SeriesDetailScreen(series: series);
            },
          ),
          GoRoute(
            path: AppRoutes.cloudBrowser,
            builder: (context, state) => const CloudBrowserScreen(),
          ),
          GoRoute(
            path: AppRoutes.profileManagement,
            builder: (context, state) => const ProfileManagementScreen(),
          ),
        ],
      ),

      // ── Full-screen routes outside the shell ──
      // VOD details, profiles, login, and multi-view
      // are intentionally full-screen. They have NO AppShell
      // parent, so we manually report currentRoute for
      // player state tracking (AppShell.updateCurrentRoute
      // only fires inside the ShellRoute).
      GoRoute(
        path: AppRoutes.vodDetails,
        builder: (context, state) {
          _reportRoute(ref, AppRoutes.vodDetails);

          final extra = state.extra;
          VodItem? item;
          String? heroTag;

          if (extra is VodItem) {
            item = extra;
          } else if (extra is Map<String, dynamic>) {
            item = extra['item'] as VodItem?;
            heroTag = extra['heroTag'] as String?;
          }

          if (item == null) {
            return const _FallbackScreen('VOD Details');
          }

          return VodDetailsScreen(item: item, heroTag: heroTag);
        },
      ),

      // Login route is not yet implemented.
      // Only reachable in debug builds for testing redirects.
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const _FallbackScreen('Login'),
        ),

      GoRoute(
        path: AppRoutes.profiles,
        builder: (context, state) => const ProfileSelectionScreen(),
      ),

      GoRoute(
        path: AppRoutes.multiview,
        builder: (context, state) {
          _reportRoute(ref, AppRoutes.multiview);
          return const MultiViewScreen();
        },
      ),
    ],
  );
});

/// Reports the current route to [playerModeProvider] for
/// screens outside the [ShellRoute]. AppShell handles
/// shell-internal routes; this covers VodDetails, MultiView,
/// and other full-screen routes that lack an AppShell parent.
///
/// Scheduled via [addPostFrameCallback] to avoid modifying
/// provider state during the build phase.
/// [PlayerModeNotifier.updateCurrentRoute] is idempotent
/// (no-op when path unchanged), so repeated calls are safe.
void _reportRoute(Ref ref, String path) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(playerModeProvider.notifier).updateCurrentRoute(path);
  });
}
