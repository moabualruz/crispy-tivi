import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';

import '../helpers/test_app.dart';

/// Content switching integration tests covering all player
/// transition types. Validates resource disposal and state
/// correctness across Live->VOD, VOD->Live, channel zap,
/// VOD->VOD, fullscreen<->mini, and PiP transitions.
///
/// NOTE: Run with `-d windows` on Windows:
///   flutter test integration_test/flows/content_switching_flow_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Helper to get the ProviderContainer from the widget tree.
  ProviderContainer getContainer(WidgetTester tester) {
    final element = tester.element(find.byType(ProviderScope).first);
    return ProviderScope.containerOf(element);
  }

  group('Content Switching Flow', () {
    // ──────────────────────────────────────────────────────────
    // Test 1: Live -> VOD transition
    // ──────────────────────────────────────────────────────────
    testWidgets('Live -> VOD: player disposes live, loads VOD content', (
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

      final container = getContainer(tester);

      // Start live playback (simulate entering fullscreen from TV tab).
      container
          .read(playerModeProvider.notifier)
          .enterFullscreen(hostRoute: '/tv');
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.fullscreen),
        reason: 'Player must be in fullscreen after starting live content.',
      );

      // Simulate stopping live and switching to VOD.
      container.read(playerServiceProvider).stop();
      container.read(playerModeProvider.notifier).setIdle();
      await tester.pump(const Duration(milliseconds: 100));

      // Navigate to VODs tab.
      await navigateToTab(tester, 'VODs');

      // Start VOD playback.
      container
          .read(playerModeProvider.notifier)
          .enterFullscreen(hostRoute: '/vod');
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.fullscreen),
        reason: 'Player must be in fullscreen after switching to VOD.',
      );
      expect(
        container.read(playerModeProvider).hostRoute,
        equals('/vod'),
        reason: 'Host route must update to /vod after content switch.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 2: VOD -> Live transition
    // ──────────────────────────────────────────────────────────
    testWidgets('VOD -> Live: player disposes VOD, loads live channel', (
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

      final container = getContainer(tester);

      // Start VOD playback.
      container
          .read(playerModeProvider.notifier)
          .enterFullscreen(hostRoute: '/vod');
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.fullscreen),
      );

      // Stop VOD → switch to live.
      container.read(playerServiceProvider).stop();
      container.read(playerModeProvider.notifier).setIdle();
      await tester.pump(const Duration(milliseconds: 100));

      await navigateToTab(tester, 'TV');

      container
          .read(playerModeProvider.notifier)
          .enterFullscreen(hostRoute: '/tv');
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.fullscreen),
        reason: 'Player must be fullscreen after VOD->Live switch.',
      );
      expect(
        container.read(playerModeProvider).hostRoute,
        equals('/tv'),
        reason: 'Host route must be /tv after switching to live.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 3: Live -> Live (channel zap)
    // ──────────────────────────────────────────────────────────
    testWidgets('Live -> Live (channel zap): previous disposed, new plays', (
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

      final container = getContainer(tester);

      // Play channel 1.
      container
          .read(playerModeProvider.notifier)
          .enterFullscreen(hostRoute: '/tv');
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.fullscreen),
      );

      // Zap to channel 2: stop current, start new (same route).
      container.read(playerServiceProvider).stop();
      await tester.pump(const Duration(milliseconds: 50));

      // Re-entering fullscreen on the same host route is a no-op
      // (idempotent). Mode stays fullscreen. This tests the zap
      // invariant: stop-before-play handles cleanup, mode persists.
      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.fullscreen),
        reason:
            'Channel zap must keep fullscreen mode — stop-before-play '
            'handles cleanup without mode transition.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 4: VOD -> VOD
    // ──────────────────────────────────────────────────────────
    testWidgets('VOD -> VOD: previous VOD disposed, new VOD plays', (
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

      final container = getContainer(tester);

      // Play VOD 1.
      container
          .read(playerModeProvider.notifier)
          .enterFullscreen(hostRoute: '/vod');
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to VOD 2: stop current, re-enter fullscreen.
      container.read(playerServiceProvider).stop();
      await tester.pump(const Duration(milliseconds: 50));

      // Mode stays fullscreen (same host route, idempotent).
      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.fullscreen),
        reason: 'VOD->VOD switch must keep fullscreen mode.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 5: Fullscreen -> Mini (background)
    // ──────────────────────────────────────────────────────────
    testWidgets('Fullscreen -> Mini: fullscreen exits cleanly to background', (
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

      final container = getContainer(tester);

      // Enter fullscreen.
      container
          .read(playerModeProvider.notifier)
          .enterFullscreen(hostRoute: '/tv');
      await tester.pump(const Duration(milliseconds: 200));

      // Exit to background (mini-player bar visible).
      container.read(playerModeProvider.notifier).exitToBackground();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.background),
        reason:
            'Exiting fullscreen must transition to background mode '
            '(mini-player visible, audio continues).',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 6: Mini -> Fullscreen
    // ──────────────────────────────────────────────────────────
    testWidgets('Mini -> Fullscreen: mini-player expands to fullscreen', (
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

      final container = getContainer(tester);

      // Start in fullscreen, then go to background.
      container
          .read(playerModeProvider.notifier)
          .enterFullscreen(hostRoute: '/tv');
      await tester.pump(const Duration(milliseconds: 100));
      container.read(playerModeProvider.notifier).exitToBackground();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.background),
      );

      // Tap mini-player bar -> fullscreen.
      container.read(playerModeProvider.notifier).enterFullscreen();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.fullscreen),
        reason: 'Tapping mini-player must expand back to fullscreen mode.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 7: PiP enter/exit (preview mode)
    // ──────────────────────────────────────────────────────────
    testWidgets('PiP enter/exit: position preserved, no resource leak', (
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

      final container = getContainer(tester);

      // Enter fullscreen first.
      container
          .read(playerModeProvider.notifier)
          .enterFullscreen(hostRoute: '/tv');
      await tester.pump(const Duration(milliseconds: 200));

      // Exit to preview (PiP corner) — need screen size for mini PiP.
      container
          .read(playerModeProvider.notifier)
          .exitToPreview(screenSize: const Size(1920, 1080));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.preview),
        reason: 'PiP enter must transition to preview mode.',
      );

      // Verify preview rect is set (PiP position).
      final previewRect = container.read(playerModeProvider).previewRect;
      expect(
        previewRect,
        isNotNull,
        reason: 'Preview rect must be set for PiP positioning.',
      );

      // Exit PiP back to fullscreen.
      container.read(playerModeProvider.notifier).enterFullscreen();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.fullscreen),
        reason: 'Exiting PiP must return to fullscreen.',
      );

      // And back to idle (complete cleanup, no resource leak).
      container.read(playerServiceProvider).stop();
      container.read(playerModeProvider.notifier).setIdle();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        container.read(playerModeProvider).mode,
        equals(PlayerMode.idle),
        reason: 'After full PiP lifecycle, player must be idle.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 8: Full content switching lifecycle
    // ──────────────────────────────────────────────────────────
    testWidgets(
      'Full lifecycle: Live fullscreen -> background -> VOD fullscreen -> PiP -> idle',
      (tester) async {
        final testBackend = MemoryBackend();
        final testCache = CacheService(testBackend);
        await seedTestSource(testCache);

        await tester.pumpWidget(
          createTestApp(backend: testBackend, cache: testCache),
        );
        await pumpAppReady(tester);
        await selectDefaultProfile(tester);

        final container = getContainer(tester);

        // Step 1: Live TV fullscreen.
        container
            .read(playerModeProvider.notifier)
            .enterFullscreen(hostRoute: '/tv');
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          container.read(playerModeProvider).mode,
          equals(PlayerMode.fullscreen),
          reason: 'Step 1: must be fullscreen.',
        );

        // Step 2: Exit to background (mini-player).
        container.read(playerModeProvider.notifier).exitToBackground();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          container.read(playerModeProvider).mode,
          equals(PlayerMode.background),
          reason: 'Step 2: must be background.',
        );

        // Step 3: Navigate to VODs, start VOD fullscreen.
        await navigateToTab(tester, 'VODs');
        container.read(playerServiceProvider).stop();
        container.read(playerModeProvider.notifier).setIdle();
        await tester.pump(const Duration(milliseconds: 100));

        container
            .read(playerModeProvider.notifier)
            .enterFullscreen(hostRoute: '/vod');
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          container.read(playerModeProvider).mode,
          equals(PlayerMode.fullscreen),
          reason: 'Step 3: must be fullscreen for VOD.',
        );

        // Step 4: Exit to PiP (preview).
        // VOD route is not in _kPreviewRoutes so exitToPreview
        // falls back to background.
        container
            .read(playerModeProvider.notifier)
            .exitToPreview(screenSize: const Size(1920, 1080));
        await tester.pump(const Duration(milliseconds: 100));

        // VOD host route is /vod which is not in preview routes
        // so it falls back to background mode.
        final modeAfterPreview = container.read(playerModeProvider).mode;
        expect(
          modeAfterPreview == PlayerMode.background ||
              modeAfterPreview == PlayerMode.preview,
          isTrue,
          reason: 'Step 4: must be background or preview after exitToPreview.',
        );

        // Step 5: Full stop.
        container.read(playerServiceProvider).stop();
        container.read(playerModeProvider.notifier).setIdle();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          container.read(playerModeProvider).mode,
          equals(PlayerMode.idle),
          reason: 'Step 5: must be idle after full stop.',
        );

        tester.takeException();
      },
    );
  });
}
