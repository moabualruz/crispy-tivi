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
import '../../features/media_servers/jellyfin/presentation/screens/jellyfin_login_screen.dart';
import '../../features/media_servers/emby/presentation/screens/emby_login_screen.dart';
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
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/player/presentation/providers/player_providers.dart';
import 'app_shell.dart';
import '../testing/test_keys.dart';

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
      key: TestKeys.notFoundScreen,
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
      // appStartupProvider guarantees settings + profiles are
      // loaded before the router is first constructed.
      // On re-invalidation (event bus), providers may briefly
      // enter loading — return null to keep current route.
      final profileState = ref.read(profileServiceProvider).value;
      final settings = ref.read(settingsNotifierProvider).value;
      if (profileState == null || settings == null) return null;

      final path = state.matchedLocation;
      final hasSources = settings.sources.isNotEmpty;

      // ── Onboarding guard (checked first) ──
      // Block all non-onboarding routes when no sources configured.
      // Must run before auto-skip so first-run users go straight
      // to onboarding without passing through home.
      final isOnboarding = path == AppRoutes.onboarding;
      final isProfiles = path == AppRoutes.profiles;

      if (!hasSources && !isOnboarding && !isProfiles) {
        return AppRoutes.onboarding;
      }
      if (hasSources && isOnboarding) {
        final defaultScreen = settings.defaultScreen;
        return defaultScreen == 'live_tv' ? AppRoutes.tv : AppRoutes.home;
      }

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
        final profiles = profileState.profiles;
        if (!isExplicit && profiles.length == 1 && !profiles.first.hasPIN) {
          // First-run with no sources: go to onboarding directly
          // instead of home. This avoids a redirect hop that
          // GoRouter may not re-evaluate.
          if (!hasSources) {
            return AppRoutes.onboarding;
          }
          // The single profile is already active (ProfileService.build
          // sets activeProfileId to profiles.first.id). Just redirect
          // to the user's preferred default screen — no state mutation
          // inside the redirect to avoid refreshListenable re-entrancy.
          final defaultScreen = settings.defaultScreen;
          return defaultScreen == 'live_tv' ? AppRoutes.tv : AppRoutes.home;
        }
      }

      // Navigation guards for role-based access
      final profile = profileState.activeProfile;
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

          // ── Jellyfin ──────────────────────────────────────────
          GoRoute(
            path: AppRoutes.jellyfinLogin,
            builder: (context, state) => const JellyfinLoginScreen(),
          ),

          // ── Emby ──────────────────────────────────────────────
          GoRoute(
            path: AppRoutes.embyLogin,
            builder: (context, state) => const EmbyLoginScreen(),
          ),

          // ── Plex ──────────────────────────────────────────────
          GoRoute(
            path: AppRoutes.plexLogin,
            builder: (context, state) => const PlexLoginScreen(),
          ),
          GoRoute(
            path: AppRoutes.seriesDetail,
            pageBuilder: (context, state) {
              final series = state.extra as VodItem?;
              if (series == null) {
                return CrispySlideTransitionPage(
                  key: state.pageKey,
                  child: const _FallbackScreen('Series Detail'),
                );
              }
              return CrispySlideTransitionPage(
                key: state.pageKey,
                child: SeriesDetailScreen(series: series),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.vodDetails,
            pageBuilder: (context, state) {
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
                return CrispySlideTransitionPage(
                  key: state.pageKey,
                  child: const _FallbackScreen('VOD Details'),
                );
              }

              return CrispySlideTransitionPage(
                key: state.pageKey,
                child: VodDetailsScreen(item: item, heroTag: heroTag),
              );
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
      // Profiles, login, and multi-view are intentionally
      // full-screen. They have NO AppShell parent, so we
      // manually report currentRoute for player state
      // tracking (AppShell.updateCurrentRoute only fires
      // inside the ShellRoute).

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
        path: AppRoutes.onboarding,
        pageBuilder:
            (context, state) =>
                _adaptivePage(context, state.pageKey, const OnboardingScreen()),
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
