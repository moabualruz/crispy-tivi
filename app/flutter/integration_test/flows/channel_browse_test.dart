import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

import '../helpers/test_app.dart';
import '../helpers/test_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Channel Browse Flow', () {
    testWidgets('TV tab shows channel names from test data', (tester) async {
      // Pre-populate channels before launching.
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveChannels(TestData.sampleChannels);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      // Select default profile.
      await selectDefaultProfile(tester);

      // Navigate to TV tab.
      await navigateToTab(tester, 'TV');

      // Drain any benign async exception.
      tester.takeException();

      // Verify the TV screen renders without errors.
      expect(find.byType(Scaffold), findsWidgets);

      // The TV screen must show seeded channel groups.
      // On large layout it shows a GroupSidebar; on compact it shows groups drill-down.
      // Either way, the seeded group names must be visible.
      expect(
        find.text('UK Entertainment'),
        findsWidgets,
        reason:
            'Seeded channel group "UK Entertainment" must be visible on the TV tab.',
      );
    });

    testWidgets('Channel groups are accessible from TV tab', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveChannels(TestData.sampleChannels);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to TV tab.
      await navigateToTab(tester, 'TV');

      // All 3 seeded channel groups must be visible.
      expect(
        find.text('UK Entertainment'),
        findsWidgets,
        reason: 'Seeded group "UK Entertainment" must be visible.',
      );
      expect(
        find.text('US News'),
        findsWidgets,
        reason: 'Seeded group "US News" must be visible.',
      );
      expect(
        find.text('Sports'),
        findsWidgets,
        reason: 'Seeded group "Sports" must be visible.',
      );

      // No crash.
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping a channel group drills into channels', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveChannels(TestData.sampleChannels);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to TV tab.
      await navigateToTab(tester, 'TV');

      // "UK Entertainment" was seeded — it must exist to drill into.
      expect(
        find.text('UK Entertainment'),
        findsWidgets,
        reason:
            'Seeded group "UK Entertainment" must be visible to drill into.',
      );
      await tester.tap(find.text('UK Entertainment').first);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // After drilling in, channel names from UK Entertainment group
      // should appear in the list.
      expect(
        find.text('BBC One'),
        findsWidgets,
        reason:
            'BBC One channel must be visible after drilling into '
            'UK Entertainment.',
      );

      // No crash from the navigation.
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Tapping a channel does not crash', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveChannels(TestData.sampleChannels);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      await selectDefaultProfile(tester);

      // Navigate to TV tab.
      await navigateToTab(tester, 'TV');

      // Drill into the seeded UK Entertainment group.
      expect(
        find.text('UK Entertainment'),
        findsWidgets,
        reason: 'Seeded group must be visible.',
      );
      await tester.tap(find.text('UK Entertainment').first);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap BBC One channel.
      expect(
        find.text('BBC One'),
        findsWidgets,
        reason: 'BBC One must be visible after drilling into group.',
      );
      await tester.tap(find.text('BBC One').first);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The app should not crash with an unrelated
      // error. Player/MediaKit errors are expected
      // in integration tests (no native player).
      final exception = tester.takeException();
      if (exception != null) {
        final msg = exception.toString();
        final isPlayerError =
            msg.contains('MediaKit') ||
            msg.contains('Player') ||
            msg.contains('Null') && msg.contains('Player');
        expect(
          isPlayerError,
          isTrue,
          reason: 'Unexpected non-player error: $exception',
        );
      }
    });
  });
}
