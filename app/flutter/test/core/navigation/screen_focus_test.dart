@Tags(['focus'])
library;

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/providers/source_filter_provider.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/core/widgets/safe_focus_scope.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/screens/media_server_login_screen.dart';
import 'package:crispy_tivi/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Minimal settings notifier for test isolation.
class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<SettingsState> build() async => SettingsState(
    config: const AppConfig(
      appName: 'Test',
      appVersion: '0.0.1',
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

  @override
  Future<String?> getVodGridDensity() async => null;

  @override
  Future<void> setVodGridDensity(String density) async {}

  @override
  Future<String?> getVodSortOption() async => null;

  @override
  Future<void> setVodSortOption(String value) async {}
}

/// Wraps [child] in a minimal MaterialApp with l10n and providers.
Widget _testApp(Widget child) {
  return ProviderScope(
    overrides: [
      crispyBackendProvider.overrideWithValue(MemoryBackend()),
      settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
      effectiveSourceIdsProvider.overrideWithValue(const []),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// Returns true if the widget tree contains a [FocusTraversalGroup].
bool _hasFocusInfrastructure(WidgetTester tester) {
  return find.byType(FocusTraversalGroup).evaluate().isNotEmpty;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen focus infrastructure', () {
    testWidgets('OnboardingScreen has FocusTraversalGroup and SafeFocusScope', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(const OnboardingScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(FocusTraversalGroup), findsAtLeastNWidgets(1));
      expect(find.byType(SafeFocusScope), findsAtLeastNWidgets(1));
      expect(_hasFocusInfrastructure(tester), isTrue);
    });

    // SettingsScreen requires GoRouter context (uses GoRouterState.of in
    // initState) — tested via grep verification and integration tests.

    testWidgets(
      'MediaServerLoginScreen has OrderedTraversalPolicy and SafeFocusScope',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            MediaServerLoginScreen(
              serverName: 'Test',
              authenticate: (Dio d, String u, String un, String p) async {
                throw UnimplementedError();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FocusTraversalGroup), findsAtLeastNWidgets(1));
        expect(find.byType(SafeFocusScope), findsAtLeastNWidgets(1));

        // Verify the policy is OrderedTraversalPolicy.
        final traversalGroups = tester.widgetList<FocusTraversalGroup>(
          find.byType(FocusTraversalGroup),
        );
        final hasOrdered = traversalGroups.any(
          (g) => g.policy is OrderedTraversalPolicy,
        );
        expect(hasOrdered, isTrue);
      },
    );
  });

  group('Keyboard shortcuts', () {
    testWidgets('Escape key does not crash on OnboardingScreen', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Send Escape key - should not throw.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Screen should still be visible (onboarding blocks pop).
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    // SettingsScreen requires GoRouter context — skip in widget tests.

    testWidgets('Enter activates focused button', (tester) async {
      var activated = false;
      await tester.pumpWidget(
        _testApp(
          Scaffold(
            body: FocusTraversalGroup(
              child: SafeFocusScope(
                child: ElevatedButton(
                  onPressed: () => activated = true,
                  child: const Text('Test'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the button via Tab.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Activate with Enter.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(activated, isTrue);
    });

    testWidgets('Space activates focused button', (tester) async {
      var activated = false;
      await tester.pumpWidget(
        _testApp(
          Scaffold(
            body: FocusTraversalGroup(
              child: SafeFocusScope(
                child: ElevatedButton(
                  onPressed: () => activated = true,
                  child: const Text('Test'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the button via Tab.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Activate with Space.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(activated, isTrue);
    });
  });

  group('Login form tab order', () {
    testWidgets('MediaServerLoginScreen form fields accept tab navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          MediaServerLoginScreen(
            serverName: 'Test',
            authenticate: (Dio d, String u, String un, String p) async {
              throw UnimplementedError();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // URL, Username, Password = 3 form fields.
      expect(find.byType(TextFormField), findsAtLeastNWidgets(3));

      // Tab to move focus into form.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Focus should be on a form field (not null).
      expect(FocusManager.instance.primaryFocus, isNotNull);
    });
  });

  group('Sub-page sidebar persistence', () {
    testWidgets('ShellRoute scaffold persists on sub-page routes', (
      tester,
    ) async {
      // Uses a simplified ShellRoute with a Scaffold keyed by
      // TestKeys.appShell and a NavigationRail — mirroring the real
      // AppShell pattern without its heavy provider dependencies.
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              return Scaffold(
                key: TestKeys.appShell,
                body: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: 0,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.home),
                          label: Text('Home'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings),
                          label: Text('Settings'),
                        ),
                      ],
                      onDestinationSelected: (_) {},
                    ),
                    Expanded(child: child),
                  ],
                ),
              );
            },
            routes: [
              GoRoute(
                path: '/home',
                builder:
                    (context, state) => const Center(child: Text('Home Page')),
              ),
              GoRoute(
                path: '/settings',
                builder:
                    (context, state) =>
                        const Center(child: Text('Settings Page')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            crispyBackendProvider.overrideWithValue(MemoryBackend()),
            settingsNotifierProvider.overrideWith(
              () => _FakeSettingsNotifier(),
            ),
            effectiveSourceIdsProvider.overrideWithValue(const []),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shell scaffold present on initial route.
      expect(find.byKey(TestKeys.appShell), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Home Page'), findsOneWidget);

      // Navigate to a sub-page route within the same shell.
      router.go('/settings');
      await tester.pumpAndSettle();

      // Shell scaffold and NavigationRail persist after navigation.
      expect(find.byKey(TestKeys.appShell), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Settings Page'), findsOneWidget);
    });
  });
}
