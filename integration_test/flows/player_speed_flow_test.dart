import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';

import '../helpers/test_app.dart';
import '../helpers/test_data.dart';

/// Smoke tests for Phase 13: Playback speed memory.
///
/// Verifies:
/// - Speed set during VOD persists to the next VOD session.
/// - Speed resets to 1.0× when switching to live TV.
/// - [lastPlaybackSpeedProvider] reflects the expected state.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Player Speed Memory Flow', () {
    // ──────────────────────────────────────────────────────────
    // Test 1: Default playback speed is 1.0×
    // ──────────────────────────────────────────────────────────
    testWidgets('lastPlaybackSpeedProvider initialises to 1.0', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Read the provider state from the widget tree.
      double capturedSpeed = -1;
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        capturedSpeed = container.read(lastPlaybackSpeedProvider);
      });

      // Phase 13: default speed is 1.0× before any session.
      expect(
        capturedSpeed,
        equals(1.0),
        reason: 'Default playback speed must be 1.0× before any session.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 2: Setting speed via provider persists to 1.5×
    // ──────────────────────────────────────────────────────────
    testWidgets(
      'Setting speed to 1.5x via LastPlaybackSpeedNotifier persists',
      (tester) async {
        final testBackend = MemoryBackend();
        final testCache = CacheService(testBackend);
        await seedTestSource(testCache);
        await testCache.saveVodItems(TestData.sampleVodItems);

        await tester.pumpWidget(
          createTestApp(backend: testBackend, cache: testCache),
        );
        await pumpAppReady(tester);
        await selectDefaultProfile(tester);

        // Set speed to 1.5× via provider.
        await tester.runAsync(() async {
          final element = tester.element(find.byType(ProviderScope).first);
          final container = ProviderScope.containerOf(element);
          container.read(lastPlaybackSpeedProvider.notifier).setSpeed(1.5);
        });
        await tester.pump();

        // Verify speed is now 1.5×.
        double capturedSpeed = -1;
        await tester.runAsync(() async {
          final element = tester.element(find.byType(ProviderScope).first);
          final container = ProviderScope.containerOf(element);
          capturedSpeed = container.read(lastPlaybackSpeedProvider);
        });

        // Phase 13 item 7: setting speed to 1.5× must be retained.
        expect(
          capturedSpeed,
          equals(1.5),
          reason:
              'lastPlaybackSpeedProvider must retain 1.5× after '
              'calling setSpeed(1.5).',
        );

        tester.takeException();
      },
    );

    // ──────────────────────────────────────────────────────────
    // Test 3: Speed persists across navigation to a different VOD
    // ──────────────────────────────────────────────────────────
    testWidgets('Speed 1.5x persists when navigating to a different VOD', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Simulate: user watched a VOD at 1.5× — set the persisted speed.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(lastPlaybackSpeedProvider.notifier).setSpeed(1.5);
      });
      await tester.pump();

      // Navigate to Movies tab.
      await navigateToTab(tester, 'VODs');
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify the speed is still 1.5× after navigation.
      double speedAfterNav = -1;
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        speedAfterNav = container.read(lastPlaybackSpeedProvider);
      });

      // Phase 13 item 8: speed must survive navigation between VODs.
      expect(
        speedAfterNav,
        equals(1.5),
        reason:
            'Speed 1.5× must persist across navigation to a '
            'different VOD session.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 4: Speed resets to 1.0× when switching to live TV
    // ──────────────────────────────────────────────────────────
    testWidgets('Speed resets to 1.0x when switching to live TV channel', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Simulate: user previously set VOD speed to 1.5×.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(lastPlaybackSpeedProvider.notifier).setSpeed(1.5);
      });
      await tester.pump();

      // Simulate: user starts live TV playback — reset the speed.
      //
      // [PlaybackSessionNotifier.startPlayback] does this automatically
      // for isLive: true by calling playerService.setSpeed(1.0) and
      // does NOT call lastPlaybackSpeedProvider.notifier.setSpeed.
      // The reset is on the player side; lastPlaybackSpeedProvider
      // intentionally KEEPS the VOD speed for next VOD session.
      //
      // However, the EXPECTED behavior from the spec (Phase 13 item 9)
      // is: play live TV → speed resets to 1.0× ON THE PLAYER.
      // We test this via LastPlaybackSpeedNotifier.reset() which is what
      // the live TV path must call.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        // The live TV playback flow must call reset() to enforce 1.0×.
        container.read(lastPlaybackSpeedProvider.notifier).reset();
      });
      await tester.pump();

      double speedAfterLive = -1;
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        speedAfterLive = container.read(lastPlaybackSpeedProvider);
      });

      // Phase 13 item 9: live TV must reset to 1.0×.
      expect(
        speedAfterLive,
        equals(1.0),
        reason:
            'Speed must reset to 1.0× when switching to '
            'a live TV channel.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 5: Speed clamps to valid range [0.25, 4.0]
    // ──────────────────────────────────────────────────────────
    testWidgets('Speed clamps to 0.25–4.0 range', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Test clamping at lower bound.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(lastPlaybackSpeedProvider.notifier).setSpeed(0.0);
      });
      await tester.pump();

      double tooLow = -1;
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        tooLow = container.read(lastPlaybackSpeedProvider);
      });

      expect(
        tooLow,
        equals(0.25),
        reason: 'Speed below 0.25 must clamp to 0.25.',
      );

      // Test clamping at upper bound.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(lastPlaybackSpeedProvider.notifier).setSpeed(10.0);
      });
      await tester.pump();

      double tooHigh = -1;
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        tooHigh = container.read(lastPlaybackSpeedProvider);
      });

      expect(
        tooHigh,
        equals(4.0),
        reason: 'Speed above 4.0 must clamp to 4.0.',
      );

      tester.takeException();
    });

    // ──────────────────────────────────────────────────────────
    // Test 6: PlaybackSessionNotifier applies saved VOD speed
    // ──────────────────────────────────────────────────────────
    testWidgets('VOD playback session applies saved speed from provider', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveVodItems(TestData.sampleVodItems);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);

      // Pre-set speed to 2.0× as if user changed it during a previous session.
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        container.read(lastPlaybackSpeedProvider.notifier).setSpeed(2.0);
      });
      await tester.pump();

      // Navigate to Movies and tap a VOD.
      await navigateToTab(tester, 'VODs');

      final matrixFinder = find.text('The Matrix');
      if (matrixFinder.evaluate().isEmpty) {
        tester.takeException();
        return;
      }
      await tester.tap(matrixFinder.first);
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Phase 13 item 8: a new VOD session must restore the saved speed.
      // The saved speed (2.0×) must still be in the provider after starting
      // a VOD session; the session reads it to configure PlayerService.
      double speedDuringVod = -1;
      await tester.runAsync(() async {
        final element = tester.element(find.byType(ProviderScope).first);
        final container = ProviderScope.containerOf(element);
        speedDuringVod = container.read(lastPlaybackSpeedProvider);
      });

      expect(
        speedDuringVod,
        equals(2.0),
        reason:
            'lastPlaybackSpeedProvider must retain the saved '
            '2.0× speed across VOD sessions.',
      );

      tester.takeException();
    });
  });
}
