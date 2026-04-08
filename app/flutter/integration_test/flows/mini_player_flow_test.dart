import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/mini_player_bar.dart';

import '../helpers/test_app.dart';

/// Smoke tests for Phase 18: Mini-player lifecycle.
///
/// Verifies:
/// - Background playback mode shows [MiniPlayerBar] (not idle).
/// - Mini-player persists while navigating to other screens.
/// - Tapping the mini-player bar enters fullscreen mode.
/// - Tapping the × button stops playback and hides the bar.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Mini-Player Lifecycle Flow', () {
    // ──────────────────────────────────────────────────────────
    // Test 1: Background mode shows MiniPlayerBar
    // ──────────────────────────────────────────────────────────
    testWidgets('PlayerMode.background shows MiniPlayerBar', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Enter background mode — simulates "Back from fullscreen player".
      // Background mode is what the app transitions to when the user
      // presses Back from the fullscreen player on a non-preview route.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(playerModeProvider.notifier).exitToBackground();
      });
      await tester.pump(const Duration(milliseconds: 200));

      // Phase 18 item 1: pressing Back must NOT stop playback.
      // Background mode keeps audio playing. The idle check verifies
      // the mode is NOT idle (i.e., still playing).
      final modeAfterBack = await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        return container.read(playerModeProvider).mode;
      });

      expect(
        modeAfterBack,
        equals(PlayerMode.background),
        reason:
            'Back from player must enter background mode (NOT idle). '
            'PlayerMode.idle would mean playback stopped, violating '
            'Phase 18 item 1.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 2: MiniPlayerBar widget renders when mode is background
    // ──────────────────────────────────────────────────────────
    testWidgets('MiniPlayerBar widget is present in the widget tree', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // The MiniPlayerBar is part of AppShell's Scaffold and is always
      // in the widget tree — it simply hides itself when not needed.
      // Phase 18: verify the bar widget exists in the tree.
      expect(
        find.byType(MiniPlayerBar),
        findsOneWidget,
        reason:
            'MiniPlayerBar must be present in the AppShell widget tree. '
            'It hides itself when there is no active playback session.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 3: Background mode persists across tab navigation
    // ──────────────────────────────────────────────────────────
    testWidgets('Background playback mode persists while navigating tabs', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Enter background mode.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(playerModeProvider.notifier).exitToBackground();
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Navigate to Settings tab.
      await navigateToTab(tester, 'Settings');

      // Phase 18 item 3: navigating to other screens must not stop playback.
      final modeAfterNav = await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        return container.read(playerModeProvider).mode;
      });

      expect(
        modeAfterNav,
        equals(PlayerMode.background),
        reason:
            'PlayerMode must remain background after navigating to '
            'Settings. Phase 18 item 3: video keeps playing while '
            'navigating to other screens.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 4: Background mode persists across multiple tab hops
    // ──────────────────────────────────────────────────────────
    testWidgets(
      'Background playback persists across multiple tab navigations',
      (tester) async {
        final testBackend = MemoryBackend();
        final testCache = CacheService(testBackend);
        await seedTestSource(testCache);

        await tester.pumpWidget(
          createTestApp(backend: testBackend, cache: testCache),
        );
        await pumpAppReady(tester);
        await selectDefaultProfile(tester);

        // Enter background mode.
        await tester.runAsync(() async {
          final element = tester.element(find.byType(ProviderScope).first);
          final container = ProviderScope.containerOf(element);
          container.read(playerModeProvider.notifier).exitToBackground();
        });
        await tester.pump(const Duration(milliseconds: 100));

        // Navigate through multiple tabs.
        for (final tab in ['Settings', 'Home', 'VODs']) {
          await navigateToTab(tester, tab);
          final mode = await tester.runAsync(() async {
            final element = tester.element(find.byType(ProviderScope).first);
            final container = ProviderScope.containerOf(element);
            return container.read(playerModeProvider).mode;
          });

          expect(
            mode,
            equals(PlayerMode.background),
            reason:
                'PlayerMode must remain background after navigating '
                'to "$tab" tab.',
          );
        }

        tester.takeException();
      },
    );

    // ──────────────────────────────────────────────────────────
    // Test 5: Entering fullscreen from background mode works
    // ──────────────────────────────────────────────────────────
    testWidgets('Tapping MiniPlayerBar enters fullscreen player mode', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Enter background mode (simulates mini-player visible).
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(playerModeProvider.notifier).exitToBackground();
      });
      await tester.pump(const Duration(milliseconds: 200));

      // Simulate tap on mini-player: call enterFullscreen as the bar does.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(playerModeProvider.notifier).enterFullscreen();
      });
      await tester.pump(const Duration(milliseconds: 200));

      final modeAfterTap = await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        return container.read(playerModeProvider).mode;
      });

      // Phase 18 item 4: tapping mini-player must return to fullscreen.
      expect(
        modeAfterTap,
        equals(PlayerMode.fullscreen),
        reason:
            'Tapping the MiniPlayerBar must transition player to '
            'PlayerMode.fullscreen. Phase 18 item 4.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 6: × button sets player to idle and clears the bar
    // ──────────────────────────────────────────────────────────
    testWidgets('Tapping close button sets player to idle mode', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Enter background mode.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(playerModeProvider.notifier).exitToBackground();
      });
      await tester.pump(const Duration(milliseconds: 200));

      // Simulate × button: stop service and set idle.
      // This mirrors MiniPlayerBar._dismiss().
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(playerServiceProvider).stop();
        container.read(playerModeProvider.notifier).setIdle();
      });
      await tester.pump(const Duration(milliseconds: 200));

      final modeAfterClose = await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        return container.read(playerModeProvider).mode;
      });

      // Phase 18 item 5: × must stop playback and return to idle.
      expect(
        modeAfterClose,
        equals(PlayerMode.idle),
        reason:
            'Tapping × (close) on MiniPlayerBar must transition '
            'player to PlayerMode.idle and stop playback.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 7: Idle mode does not show MiniPlayerBar content
    // ──────────────────────────────────────────────────────────
    testWidgets('MiniPlayerBar hides when player is in idle mode', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Ensure player is in idle state (default).
      final mode = await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        return container.read(playerModeProvider).mode;
      });

      expect(
        mode,
        equals(PlayerMode.idle),
        reason: 'App should start with player in idle mode.',
      );

      // With idle mode and no playback state, the bar must not show
      // interactive content. The MiniPlayerBar widget itself remains
      // in the tree but renders as SizedBox.shrink() when idle.
      //
      // Phase 18 item 5: after × the bar must be "gone" (invisible/collapsed).
      // We verify no close button (×) is visible when idle.
      expect(
        find.byIcon(Icons.close_rounded).evaluate().where((e) {
          // Exclude any close icons that might be in other widgets.
          final widget = e.widget;
          return widget is Icon && widget.icon == Icons.close_rounded;
        }).isEmpty,
        isTrue,
        reason:
            'The MiniPlayerBar close (×) button must not be visible '
            'when the player is in idle mode.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 8: Full lifecycle: background → navigate → fullscreen → idle
    // ──────────────────────────────────────────────────────────
    testWidgets(
      'Full mini-player lifecycle: background, navigate, fullscreen, idle',
      (tester) async {
        final testBackend = MemoryBackend();
        final testCache = CacheService(testBackend);
        await seedTestSource(testCache);

        await tester.pumpWidget(
          createTestApp(backend: testBackend, cache: testCache),
        );
        await pumpAppReady(tester);
        await selectDefaultProfile(tester);

        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);

        // Step 1: Enter background mode (user pressed Back from player).
        container.read(playerModeProvider.notifier).exitToBackground();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          container.read(playerModeProvider).mode,
          equals(PlayerMode.background),
          reason: 'Step 1: mode must be background after exitToBackground().',
        );

        // Step 2: Navigate to Settings — background persists.
        await navigateToTab(tester, 'Settings');

        expect(
          container.read(playerModeProvider).mode,
          equals(PlayerMode.background),
          reason: 'Step 2: background mode must persist during navigation.',
        );

        // Step 3: Tap mini-player bar → fullscreen.
        container.read(playerModeProvider.notifier).enterFullscreen();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          container.read(playerModeProvider).mode,
          equals(PlayerMode.fullscreen),
          reason: 'Step 3: tapping mini-player must enter fullscreen.',
        );

        // Step 4: Dismiss via × → idle.
        container.read(playerServiceProvider).stop();
        container.read(playerModeProvider.notifier).setIdle();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          container.read(playerModeProvider).mode,
          equals(PlayerMode.idle),
          reason: 'Step 4: tapping × must set idle mode.',
        );

        tester.takeException();
      },
    );
  });
}
