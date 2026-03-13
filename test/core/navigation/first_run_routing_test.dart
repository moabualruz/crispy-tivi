// Tests for first-run routing logic in GoRouter redirect.
//
// Verifies:
//   - Zero profiles → default auto-created → onboarding (no sources)
//   - Single profile without PIN → auto-select → home
//   - Multiple profiles → profile selection screen
//   - After onboarding (sources configured) → navigate to home
//
// Strategy: Builds a GoRouter with the same redirect logic as the
// production [goRouterProvider] but uses lightweight page stubs
// instead of AppShell (which has periodic timers that cause teardown
// failures in widget tests). The redirect function is tested by
// reading provider state injected via overrides.

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/profiles/data/profile_service.dart';
import 'package:crispy_tivi/features/profiles/domain/entities/user_profile.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Mocks ────────────────────────────────────────────────────

class _MockPlayerService extends Mock implements PlayerService {}

// ─── Fake SettingsNotifiers ───────────────────────────────────

AppConfig _testConfig() => const AppConfig(
  appName: 'Test',
  appVersion: '0.0.1',
  api: ApiConfig(
    baseUrl: 'http://localhost',
    backendPort: 8080,
    connectTimeoutMs: 5000,
    receiveTimeoutMs: 5000,
    sendTimeoutMs: 5000,
  ),
  player: PlayerConfig(
    defaultBufferDurationMs: 2000,
    autoPlay: false,
    defaultAspectRatio: '16:9',
  ),
  theme: ThemeConfig(
    mode: 'dark',
    seedColorHex: '#6750A4',
    useDynamicColor: false,
  ),
  features: FeaturesConfig(
    iptvEnabled: true,
    jellyfinEnabled: false,
    plexEnabled: false,
    embyEnabled: false,
  ),
  cache: CacheConfig(
    epgRefreshIntervalMinutes: 360,
    channelListRefreshIntervalMinutes: 60,
    maxCachedEpgDays: 7,
  ),
);

/// Settings with no sources configured (first-run state).
class _NoSourcesSettingsNotifier extends SettingsNotifier {
  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _testConfig(), sources: const []);
}

/// Settings with sources configured (post-onboarding state).
class _WithSourcesSettingsNotifier extends SettingsNotifier {
  @override
  Future<SettingsState> build() async => SettingsState(
    config: _testConfig(),
    sources: const [
      PlaylistSource(
        id: 'src1',
        name: 'Test Source',
        url: 'http://example.com/playlist.m3u',
        type: PlaylistSourceType.m3u,
      ),
    ],
  );
}

// ─── Helpers ──────────────────────────────────────────────────

_MockPlayerService _buildMockPlayerService() {
  final mock = _MockPlayerService();
  when(() => mock.stop()).thenAnswer((_) async {});
  when(() => mock.forceStateEmit()).thenReturn(null);
  when(
    () => mock.stateStream,
  ).thenAnswer((_) => const Stream<PlaybackState>.empty());
  when(() => mock.state).thenReturn(const PlaybackState());
  return mock;
}

/// Minimal page stub — avoids mounting AppShell and its periodic timers.
class _Page extends StatelessWidget {
  const _Page(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(name));
}

/// Provider that creates a GoRouter with the SAME redirect logic as
/// production but lightweight page stubs instead of AppShell.
///
/// This mirrors the redirect in `goRouterProvider` exactly, ensuring
/// test coverage of the actual routing decisions without the heavy
/// shell widget tree.
final _testRouterProvider = Provider<GoRouter>((ref) {
  final profileRefresh = ChangeNotifier();
  final settingsRefresh = ChangeNotifier();
  ref.onDispose(() {
    profileRefresh.dispose();
    settingsRefresh.dispose();
  });
  // ignore: invalid_use_of_protected_member
  ref.listen(
    profileServiceProvider,
    (_, _) => profileRefresh.notifyListeners(),
  );
  ref.listen(
    settingsNotifierProvider,
    // ignore: invalid_use_of_protected_member
    (_, _) => settingsRefresh.notifyListeners(),
  );

  return GoRouter(
    refreshListenable: Listenable.merge([profileRefresh, settingsRefresh]),
    redirect: (context, state) {
      final profileState = ref.read(profileServiceProvider).value;
      final settings = ref.read(settingsNotifierProvider).value;
      if (profileState == null || settings == null) return null;

      final path = state.matchedLocation;
      final hasSources = settings.sources.isNotEmpty;

      // ── Onboarding guard ──
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
      if (path == AppRoutes.profiles) {
        final isExplicit =
            state.extra is Map<String, dynamic> &&
            (state.extra as Map<String, dynamic>)['explicit'] == true;
        final profiles = profileState.profiles;
        if (!isExplicit && profiles.length == 1 && !profiles.first.hasPIN) {
          if (!hasSources) {
            return AppRoutes.onboarding;
          }
          final defaultScreen = settings.defaultScreen;
          return defaultScreen == 'live_tv' ? AppRoutes.tv : AppRoutes.home;
        }
      }

      // ── Role-based guards ──
      final profile = profileState.activeProfile;
      if (profile != null) {
        if (path == AppRoutes.profileManagement && !profile.isAdmin) {
          return AppRoutes.home;
        }
        if (path == AppRoutes.settings && !profile.canAccessSettings) {
          return AppRoutes.home;
        }
      }

      return null;
    },
    initialLocation: AppRoutes.profiles,
    routes: [
      GoRoute(path: AppRoutes.home, builder: (_, _) => const _Page('Home')),
      GoRoute(path: AppRoutes.tv, builder: (_, _) => const _Page('Live TV')),
      GoRoute(
        path: AppRoutes.profiles,
        builder: (_, _) => const _Page('Profiles'),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const _Page('Onboarding'),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const _Page('Settings'),
      ),
    ],
  );
});

/// Builds a test app with lightweight router and overridden providers.
Widget _buildApp({
  required MemoryBackend backend,
  required SettingsNotifier Function() settingsFactory,
  CacheService? cacheService,
}) {
  final cache = cacheService ?? CacheService(backend);
  final mockPlayerService = _buildMockPlayerService();
  return ProviderScope(
    overrides: [
      crispyBackendProvider.overrideWithValue(backend),
      cacheServiceProvider.overrideWithValue(cache),
      settingsNotifierProvider.overrideWith(settingsFactory),
      playerServiceProvider.overrideWithValue(mockPlayerService),
      playbackStateProvider.overrideWith(
        (_) => const Stream<PlaybackState>.empty(),
      ),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final router = ref.watch(_testRouterProvider);
        return MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
        );
      },
    ),
  );
}

/// Reads the current router path from the container.
String _currentPath(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  final router = container.read(_testRouterProvider);
  return router.routerDelegate.currentConfiguration.uri.path;
}

/// Standard pump sequence for async provider resolution + redirect.
Future<void> _pumpForRedirects(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
  await tester.pumpAndSettle();
}

// ─── Tests ────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.useGoogleFonts = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('First-run routing', () {
    testWidgets(
      'zero profiles → auto-creates default → redirects to onboarding (no sources)',
      (tester) async {
        final backend = MemoryBackend();

        await tester.pumpWidget(
          _buildApp(
            backend: backend,
            settingsFactory: _NoSourcesSettingsNotifier.new,
          ),
        );
        await _pumpForRedirects(tester);

        expect(_currentPath(tester), AppRoutes.onboarding);
      },
    );

    testWidgets(
      'single profile without PIN → auto-select → home (with sources)',
      (tester) async {
        final backend = MemoryBackend();

        await tester.pumpWidget(
          _buildApp(
            backend: backend,
            settingsFactory: _WithSourcesSettingsNotifier.new,
          ),
        );
        await _pumpForRedirects(tester);

        expect(_currentPath(tester), AppRoutes.home);
      },
    );

    testWidgets('multiple profiles → shows profile selection', (tester) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);
      // Pre-save two profiles before ProfileService.build runs.
      await cache.saveProfile(
        const UserProfile(
          id: 'p1',
          name: 'User 1',
          avatarIndex: 0,
          isActive: true,
          pinVersion: 1,
        ),
      );
      await cache.saveProfile(
        const UserProfile(
          id: 'p2',
          name: 'User 2',
          avatarIndex: 1,
          isActive: false,
          pinVersion: 1,
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          backend: backend,
          cacheService: cache,
          settingsFactory: _WithSourcesSettingsNotifier.new,
        ),
      );
      await _pumpForRedirects(tester);

      // Multiple profiles → should stay on /profiles.
      expect(_currentPath(tester), AppRoutes.profiles);
    });

    testWidgets(
      'after onboarding (sources configured) → redirects away from onboarding to home',
      (tester) async {
        final backend = MemoryBackend();

        await tester.pumpWidget(
          _buildApp(
            backend: backend,
            settingsFactory: _WithSourcesSettingsNotifier.new,
          ),
        );
        await _pumpForRedirects(tester);

        // Now at home. Try navigating to onboarding —
        // should redirect back since sources exist.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        container.read(_testRouterProvider).go(AppRoutes.onboarding);
        await _pumpForRedirects(tester);

        expect(_currentPath(tester), isNot(AppRoutes.onboarding));
        expect(_currentPath(tester), AppRoutes.home);
      },
    );
  });
}
