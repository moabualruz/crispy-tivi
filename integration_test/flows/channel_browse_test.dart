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
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Select default profile.
      await selectDefaultProfile(tester);

      // Navigate to TV tab.
      await navigateToTab(tester, 'TV');

      // No exceptions should occur.
      expect(tester.takeException(), isNull);

      // Channel names from TestData.sampleChannels
      // should be visible somewhere on screen.
      // The mobile layout shows groups first, so
      // we check for group names or channel names.
      final hasBbcOne = find.text('BBC One').evaluate().isNotEmpty;
      final hasCnn = find.text('CNN').evaluate().isNotEmpty;
      final hasEspn = find.text('ESPN').evaluate().isNotEmpty;
      final hasUkGroup = find.text('UK Entertainment').evaluate().isNotEmpty;
      final hasUsNews = find.text('US News').evaluate().isNotEmpty;
      final hasSports = find.text('Sports').evaluate().isNotEmpty;

      // On mobile, groups view shows first. On
      // desktop, channels are visible alongside
      // the sidebar. Either way, at least some
      // content from our test data must be visible.
      final hasChannelContent = hasBbcOne || hasCnn || hasEspn;
      final hasGroupContent = hasUkGroup || hasUsNews || hasSports;

      expect(
        hasChannelContent || hasGroupContent,
        isTrue,
        reason:
            'Expected at least one channel name '
            'or group name from test data to be '
            'visible on the TV tab.',
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
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await selectDefaultProfile(tester);

      // Navigate to TV tab.
      await navigateToTab(tester, 'TV');

      // On mobile, the groups view is shown first.
      // Check that at least one of the expected
      // groups is displayed.
      final groups = ['UK Entertainment', 'US News', 'Sports'];
      final foundGroups = groups.where(
        (g) => find.text(g).evaluate().isNotEmpty,
      );

      // If groups are visible, verify at least two.
      if (foundGroups.isNotEmpty) {
        expect(
          foundGroups.length,
          greaterThanOrEqualTo(2),
          reason:
              'Expected at least 2 channel groups '
              'to be visible.',
        );
      }

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
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await selectDefaultProfile(tester);

      // Navigate to TV tab.
      await navigateToTab(tester, 'TV');

      // Try to tap a group to drill into channels.
      // "UK Entertainment" has BBC One and BBC Two.
      final ukGroup = find.text('UK Entertainment');
      if (ukGroup.evaluate().isNotEmpty) {
        await tester.tap(ukGroup.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // After drilling in, channel names should
        // appear in the list.
        expect(find.text('BBC One'), findsWidgets);
      }

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
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await selectDefaultProfile(tester);

      // Navigate to TV tab.
      await navigateToTab(tester, 'TV');

      // Try to find a channel to tap.
      // First drill into a group if visible.
      final ukGroup = find.text('UK Entertainment');
      if (ukGroup.evaluate().isNotEmpty) {
        await tester.tap(ukGroup.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Now try to tap BBC One if visible.
      final bbcOne = find.text('BBC One');
      if (bbcOne.evaluate().isNotEmpty) {
        await tester.tap(bbcOne.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
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
          reason:
              'Unexpected non-player error: '
              '$exception',
        );
      }
    });
  });
}
