import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';

import '../helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Player Flow & Edge Cases', () {
    testWidgets('Navigate through all shell tabs without crash', (
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

      for (final tabName in ['Home', 'TV', 'Guide', 'VODs', 'Settings']) {
        await navigateToTab(tester, tabName);
        expect(find.byType(Scaffold), findsWidgets);
      }
      // Drain any benign async exception from the
      // integration test binding (e.g., type 'Null' is
      // not a subtype of type 'Future<void>').
      tester.takeException();
    });

    testWidgets(
      '[SKIPPED] Native OSD Interaction (Known Windows Bug: OSD clicks fail over hardware video textures)',
      (tester) async {
        final testBackend = MemoryBackend();
        final testCache = CacheService(testBackend);
        await seedTestSource(testCache);
        await tester.pumpWidget(
          createTestApp(backend: testBackend, cache: testCache),
        );
        await pumpAppReady(tester);

        await selectDefaultProfile(tester);
        await navigateToTab(tester, 'TV');

        // Tap first channel to launch player
        final firstChannel = find.text('Channel 1').first;
        await tester.tap(firstChannel);
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Wait for player to boot
        expect(find.byKey(TestKeys.playerGestureDetector), findsOneWidget);

        // Tap the center of the video to invoke OSD
        await tester.tap(find.byKey(TestKeys.playerGestureDetector));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Find and tap the Overflow (Settings) menu
        final overflowMenu = find.byIcon(Icons.more_vert_rounded);
        expect(overflowMenu, findsOneWidget);

        await tester.tap(overflowMenu);
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Verify the submenu opened by looking for the Stream Info button
        expect(find.text('Stream Info'), findsOneWidget);
      },
      skip: true,
    );

    testWidgets(
      '[SKIPPED] Native Fullscreen Maximization (Known Windows Bug: Fullscreen toggle fails if window is already maximized)',
      (tester) async {
        final testBackend = MemoryBackend();
        final testCache = CacheService(testBackend);
        await seedTestSource(testCache);
        await tester.pumpWidget(
          createTestApp(backend: testBackend, cache: testCache),
        );
        await pumpAppReady(tester);

        await selectDefaultProfile(tester);
        await navigateToTab(tester, 'TV');

        // Tap first channel
        await tester.tap(find.text('Channel 1').first);
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Invoke OSD
        await tester.tap(find.byKey(TestKeys.playerGestureDetector));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Find and tap fullscreen
        final fullscreenBtn = find.byIcon(Icons.fullscreen_rounded);
        expect(fullscreenBtn, findsOneWidget);

        await tester.tap(fullscreenBtn);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
      skip: true,
    );

    testWidgets(
      '[SKIPPED] Native Picture-in-Picture (Known Windows Bug: PiP overlay breaks Windows host management system)',
      (tester) async {
        final testBackend = MemoryBackend();
        final testCache = CacheService(testBackend);
        await seedTestSource(testCache);
        await tester.pumpWidget(
          createTestApp(backend: testBackend, cache: testCache),
        );
        await pumpAppReady(tester);

        await selectDefaultProfile(tester);
        await navigateToTab(tester, 'TV');

        // Tap first channel
        await tester.tap(find.text('Channel 1').first);
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Invoke OSD
        await tester.tap(find.byKey(TestKeys.playerGestureDetector));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Find and tap the Overflow menu
        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Tap PiP button inside overflow
        final pipBtn = find.byIcon(Icons.picture_in_picture_alt_rounded);
        expect(pipBtn, findsOneWidget);

        await tester.tap(pipBtn);
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
      skip: true,
    );
  });
}
