import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/navigation/app_router.dart';
import 'package:crispy_tivi/features/profiles/data/profile_service.dart';
import 'package:crispy_tivi/features/profiles/domain/entities/user_profile.dart';
import 'package:crispy_tivi/features/profiles/domain/enums/dvr_permission.dart';
import 'package:crispy_tivi/features/profiles/domain/enums/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ── Minimal AppConfig ──────────────────────────────────────────────────────

AppConfig _minimalConfig() => const AppConfig(
  appName: 'Test',
  appVersion: '0.0.0',
  api: ApiConfig(
    baseUrl: 'http://test',
    backendPort: 8080,
    connectTimeoutMs: 5000,
    receiveTimeoutMs: 5000,
    sendTimeoutMs: 5000,
  ),
  player: PlayerConfig(
    defaultBufferDurationMs: 2000,
    autoPlay: true,
    defaultAspectRatio: '16:9',
  ),
  theme: ThemeConfig(
    mode: 'dark',
    seedColorHex: '#3B82F6',
    useDynamicColor: false,
  ),
  features: FeaturesConfig(
    iptvEnabled: true,
    jellyfinEnabled: false,
    plexEnabled: false,
    embyEnabled: false,
  ),
  cache: CacheConfig(
    epgRefreshIntervalMinutes: 60,
    channelListRefreshIntervalMinutes: 30,
    maxCachedEpgDays: 7,
  ),
);

// ── Fake providers ─────────────────────────────────────────────────────────

/// A settings notifier that can be pre-configured with a list of sources.
class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier({List<PlaylistSource> sources = const []})
    : _sources = sources;

  final List<PlaylistSource> _sources;

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig(), sources: _sources);

  @override
  Future<void> addSource(PlaylistSource source) async {}

  @override
  Future<void> removeSource(String id) async {}

  // Stubs for remaining SettingsNotifier methods (not exercised by these tests).
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// A profile service that returns a pre-configured state.
class _FakeProfileService extends ProfileService {
  _FakeProfileService({UserProfile? activeProfile})
    : _activeProfile = activeProfile;

  final UserProfile? _activeProfile;

  @override
  Future<ProfileState> build() async {
    if (_activeProfile == null) {
      return const ProfileState(profiles: [], activeProfileId: '');
    }
    return ProfileState(
      profiles: [_activeProfile],
      activeProfileId: _activeProfile.id,
    );
  }
}

// ── Test helpers ───────────────────────────────────────────────────────────

/// A profile with admin role that has no PIN.
const _defaultProfile = UserProfile(
  id: 'p1',
  name: 'Test',
  role: UserRole.admin,
  dvrPermission: DvrPermission.full,
  isActive: true,
);

/// An M3U source for testing "sources exist" scenario.
const _m3uSource = PlaylistSource(
  id: 'src_1',
  name: 'My Playlist',
  url: 'http://test.m3u',
  type: PlaylistSourceType.m3u,
);

/// Wraps the app with ProviderScope overrides and pumps it.
///
/// Returns the [GoRouter] so callers can navigate to different paths.
Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  List<PlaylistSource> sources = const [],
  UserProfile? activeProfile = _defaultProfile,
}) async {
  final backend = MemoryBackend();
  final fakeSettings = _FakeSettingsNotifier(sources: sources);
  final fakeProfiles = _FakeProfileService(activeProfile: activeProfile);

  late GoRouter router;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        crispyBackendProvider.overrideWithValue(backend),
        cacheServiceProvider.overrideWithValue(CacheService(backend)),
        settingsNotifierProvider.overrideWith(() => fakeSettings),
        profileServiceProvider.overrideWith(() => fakeProfiles),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          router = ref.watch(goRouterProvider);
          return MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    ),
  );

  // Allow the async notifiers to settle
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));

  return router;
}

void main() {
  // ── REQ-03 Scenario 1: No sources + active profile → redirect to /onboarding

  testWidgets(
    'no sources + active profile: navigating to /home redirects to /onboarding',
    (tester) async {
      final router = await _pumpApp(
        tester,
        sources: [], // no sources
        activeProfile: _defaultProfile, // active profile exists
      );

      // Navigate to home (requires sources)
      router.go(AppRoutes.home);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.onboarding,
      );
    },
  );

  // ── REQ-03 Scenario 2: Sources exist → redirect away from /onboarding

  testWidgets('sources exist: navigating to /onboarding redirects to /home', (
    tester,
  ) async {
    final router = await _pumpApp(
      tester,
      sources: [_m3uSource], // sources configured
      activeProfile: _defaultProfile,
    );

    // Navigate to onboarding when sources already exist
    router.go(AppRoutes.onboarding);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Should be redirected away from /onboarding
    final path = router.routeInformationProvider.value.uri.path;
    expect(path, isNot(AppRoutes.onboarding));
    expect(path, AppRoutes.home);
  });

  // ── REQ-03 Scenario 3: No sources + no active profile + /profiles → no redirect

  testWidgets(
    'no sources + no active profile: /profiles is exempt from onboarding guard',
    (tester) async {
      final router = await _pumpApp(
        tester,
        sources: [], // no sources
        activeProfile: null, // no active profile — must select one
      );

      // Navigate to profiles
      router.go(AppRoutes.profiles);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // /profiles must NOT be redirected to /onboarding when no profile is active
      final path = router.routeInformationProvider.value.uri.path;
      expect(path, AppRoutes.profiles);
    },
  );

  // ── REQ-03 Scenario 4: No sources + active profile + /profiles → not redirected to /onboarding

  testWidgets(
    'no sources + active profile: /profiles is NOT redirected to /onboarding',
    (tester) async {
      final router = await _pumpApp(
        tester,
        sources: [], // no sources
        activeProfile: _defaultProfile, // profile is active
      );

      router.go(AppRoutes.profiles);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // /profiles must NOT be redirected to /onboarding — the onboarding
      // guard exempts both /profiles and /onboarding paths. The auto-skip
      // profile logic (single no-PIN profile) may redirect to /home, but
      // never to /onboarding.
      final path = router.routeInformationProvider.value.uri.path;
      expect(path, isNot(AppRoutes.onboarding));
    },
  );
}
