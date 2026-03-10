// Tests for AppShell keyboard shortcuts (Phase 17, items 1–4).
//
// Strategy:
//   - Unit-test the shortcut map logic by inspecting
//     [CallbackShortcuts] bindings built in [AppShell._shortcutsFor].
//   - Widget-test the shell with a real GoRouter so key events
//     drive actual navigation.
//
// Heavy providers (profileService, playerService, configService)
// are overridden with in-memory stubs so the test does not reach
// the network or file system.

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
import 'package:crispy_tivi/core/navigation/app_shell.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Fake SettingsNotifier ────────────────────────────────────

/// Minimal [SettingsNotifier] that does not require a live backend.
class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<SettingsState> build() async => SettingsState(
    config: const AppConfig(
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
    ),
  );
}

// ─── Router helper ────────────────────────────────────────────

/// Builds a [GoRouter] that places [AppShell] as a shell and
/// registers all nav routes so digit shortcuts can navigate.
GoRouter _buildRouter({String initial = AppRoutes.home}) {
  final routes = <RouteBase>[
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, _) => const _Page('Home')),
        GoRoute(
          path: AppRoutes.customSearch,
          builder: (_, _) => const _Page('Search'),
        ),
        GoRoute(path: AppRoutes.tv, builder: (_, _) => const _Page('Live TV')),
        GoRoute(path: AppRoutes.epg, builder: (_, _) => const _Page('Guide')),
        GoRoute(path: AppRoutes.vod, builder: (_, _) => const _Page('Movies')),
        GoRoute(
          path: AppRoutes.series,
          builder: (_, _) => const _Page('Series'),
        ),
        GoRoute(path: AppRoutes.dvr, builder: (_, _) => const _Page('DVR')),
        GoRoute(
          path: AppRoutes.favorites,
          builder: (_, _) => const _Page('Favorites'),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, _) => const _Page('Settings'),
        ),
      ],
    ),
  ];

  return GoRouter(initialLocation: initial, routes: routes);
}

/// Wraps the app in [ProviderScope] + [MaterialApp.router].
Widget _buildApp(GoRouter router) {
  final backend = MemoryBackend();
  return ProviderScope(
    overrides: [
      crispyBackendProvider.overrideWithValue(backend),
      cacheServiceProvider.overrideWithValue(CacheService(backend)),
      settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
      playbackStateProvider.overrideWith(
        (_) => const Stream<PlaybackState>.empty(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.fromThemeState(const ThemeState()).theme,
    ),
  );
}

// ─── Minimal page widget ─────────────────────────────────────

class _Page extends StatelessWidget {
  const _Page(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Text(name);
}

// ─── Tests ────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.useGoogleFonts = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppShell keyboard shortcuts — search (/)', () {
    testWidgets('pressing / navigates to search route', (tester) async {
      final router = _buildRouter(initial: AppRoutes.home);
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      // Confirm we start on Home.
      expect(find.text('Home'), findsOneWidget);

      // Press "/" — should trigger _openSearch → go(search).
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      // Microtask deferred navigation — pump a few frames.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.customSearch,
      );
    });
  });

  group('AppShell keyboard shortcuts — digit navigation (1–9)', () {
    testWidgets('pressing 1 navigates to the first nav destination', (
      tester,
    ) async {
      // Side nav (1920×1080 → large layout) has 9 destinations.
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = _buildRouter(initial: AppRoutes.customSearch);
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      // Press digit 1 — sideDestinations[0] == Home.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.home,
      );
    });

    testWidgets('pressing 2 navigates to the second side destination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = _buildRouter(initial: AppRoutes.home);
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      // sideDestinations[1] == Search.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.customSearch,
      );
    });

    testWidgets('pressing 3 navigates to the third side destination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = _buildRouter(initial: AppRoutes.home);
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      // sideDestinations[2] == Live TV.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.tv);
    });

    testWidgets('digit keys disabled on channel (TV) screen', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Start on TV screen — digit shortcuts must be disabled.
      final router = _buildRouter(initial: AppRoutes.tv);
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      final beforePath = router.routerDelegate.currentConfiguration.uri.path;

      // Press digit 1 on TV screen — should be ignored (direct-dial mode).
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Route must NOT have changed.
      expect(router.routerDelegate.currentConfiguration.uri.path, beforePath);
    });
  });

  group('AppShell keyboard shortcuts — ? shortcut help overlay', () {
    testWidgets('pressing ? (Shift+/) shows KeyboardShortcutsOverlay dialog', (
      tester,
    ) async {
      // Desktop layout (840+ dp) is required for the ? shortcut to be active.
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = _buildRouter(initial: AppRoutes.home);
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      // Press Shift+/ which maps to "?" in ASCII.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      // The keyboard shortcuts overlay is an AlertDialog —
      // verify it appeared in the widget tree.
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('AppShell keyboard shortcuts — Escape back navigation', () {
    testWidgets('pressing Escape pops navigation when route is not Home', (
      tester,
    ) async {
      final router = _buildRouter(initial: AppRoutes.settings);
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      // Confirm we are on Settings, not Home.
      expect(find.text('Settings'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Escape with no push history goes to Home (fallback in _handleBack).
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.home,
      );
    });

    testWidgets('pressing Escape on Home does not navigate away', (
      tester,
    ) async {
      final router = _buildRouter(initial: AppRoutes.home);
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Escape on Home stays on Home — no route change.
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.home,
      );
    });
  });
}
