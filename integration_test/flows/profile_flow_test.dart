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

  group('Profile Flow', () {
    testWidgets('Shows profile selection with "Who\'s watching?" header', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      // Seed 2 profiles so profile selection screen shows
      // (auto-skip triggers when only 1 profile with no PIN).
      await seedMultipleProfiles(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      // The profile selection screen should show
      // the "Who's watching?" header text.
      expect(find.text("Who's watching?"), findsOneWidget);

      // Default profile should exist.
      expect(find.text('Default'), findsWidgets);
    });

    testWidgets('Shows "Add Profile" button with add icon', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await seedMultipleProfiles(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      // The "Add Profile" tile should be visible.
      expect(find.byKey(TestKeys.addProfileButton), findsOneWidget);

      // The person-add icon should be present on the tile.
      expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
    });

    testWidgets('Tapping "Add Profile" opens dialog with title', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await seedMultipleProfiles(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      // Tap the "Add Profile" tile.
      final addBtn = find.byKey(TestKeys.addProfileButton);
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The dialog should appear with title text,
      // a name field label, and avatar picker.
      expect(find.text('Add Profile'), findsWidgets);
      expect(find.text('Profile Name'), findsOneWidget);
      expect(find.text('Choose Avatar'), findsOneWidget);

      // Cancel and Create buttons should be present.
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('Selecting default profile navigates to app shell', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await seedMultipleProfiles(testCache);
      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);

      // Verify we are on profile selection.
      expect(find.text("Who's watching?"), findsOneWidget);

      // Tap the default profile.
      final defaultProfile = find.text('Default');
      expect(defaultProfile, findsWidgets);
      await tester.tap(defaultProfile.first);
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Should navigate away from profile selection.
      // The "Who's watching?" header should be gone.
      expect(find.text("Who's watching?"), findsNothing);

      // The app shell should render with a Scaffold.
      expect(find.byType(Scaffold), findsWidgets);

      // After profile selection, navigation items must be present in the app shell.
      expect(
        find.byKey(TestKeys.navItem('Home')),
        findsOneWidget,
        reason: 'Home nav item must be present after profile selection.',
      );
      expect(
        find.byKey(TestKeys.navItem('Settings')),
        findsOneWidget,
        reason: 'Settings nav item must be present after profile selection.',
      );
    });
  });
}
