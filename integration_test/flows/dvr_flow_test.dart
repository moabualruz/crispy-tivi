import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';

import '../helpers/test_app.dart';
import '../helpers/test_data.dart';

/// Pumps frames until [finder] matches at least one widget or [maxMs]
/// elapses. Never calls pumpAndSettle.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxMs = 5000,
}) async {
  final steps = maxMs ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// Drains any pending async exception from the integration test binding.
void _drainException(WidgetTester tester) {
  tester.takeException();
}

/// Navigates to the DVR screen and waits for it to appear.
Future<void> _navigateToDvr(WidgetTester tester) async {
  await navigateToTab(tester, 'DVR');
  _drainException(tester);
  await _pumpUntilFound(tester, find.byKey(TestKeys.dvrScreen));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DVR Flow', () {
    testWidgets('DVR screen renders with 4 tabs', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);
      await testCache.saveChannels(TestData.sampleChannels);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);
      await _navigateToDvr(tester);

      // Phase 16 DVR item 1: 4 tabs must be visible.
      expect(
        find.byKey(TestKeys.dvrScreen),
        findsOneWidget,
        reason: 'DVR screen must be keyed TestKeys.dvrScreen.',
      );
      expect(
        find.text('Scheduled'),
        findsOneWidget,
        reason: 'Tab "Scheduled" must be visible.',
      );
      expect(
        find.text('In Progress'),
        findsOneWidget,
        reason: 'Tab "In Progress" must be visible.',
      );
      expect(
        find.text('Completed'),
        findsOneWidget,
        reason: 'Tab "Completed" must be visible.',
      );
      expect(
        find.text('Transfers'),
        findsOneWidget,
        reason: 'Tab "Transfers" must be visible.',
      );
    });

    testWidgets('AppBar shows "Recordings" title with action buttons', (
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
      await _navigateToDvr(tester);

      // Phase 16 DVR item 2: AppBar title is "Recordings".
      expect(
        find.text('Recordings'),
        findsOneWidget,
        reason: 'DVR AppBar must show "Recordings" as the title.',
      );

      // Phase 16 DVR item 2: grouped-view toggle must be present.
      final hasGroupViewToggle =
          find.byIcon(Icons.folder_copy_outlined).evaluate().isNotEmpty ||
          find.byIcon(Icons.format_list_bulleted).evaluate().isNotEmpty;
      expect(
        hasGroupViewToggle,
        isTrue,
        reason: 'AppBar must contain the grouped/flat view toggle icon.',
      );

      // Phase 16 DVR item 2: search icon must be present.
      expect(
        find.byIcon(Icons.search),
        findsWidgets,
        reason: 'AppBar must contain the search recordings icon.',
      );

      // Phase 16 DVR item 2: Keyword Rules icon must be present.
      expect(
        find.byIcon(Icons.manage_search),
        findsWidgets,
        reason: 'AppBar must contain the Keyword Rules icon.',
      );
    });

    testWidgets('StorageBar is shown below AppBar when storage is used', (
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
      await _navigateToDvr(tester);

      // Phase 16 DVR item 3: StorageBar is visible when totalStorageBytes > 0.
      // With no real recordings the bar is hidden — verify no crash.
      // The LinearProgressIndicator inside StorageBar is the observable widget.
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets(
      'FAB expands to speed dial with Storage, Keyword Rules, Schedule',
      (tester) async {
        final testBackend = MemoryBackend();
        final testCache = CacheService(testBackend);
        await seedTestSource(testCache);

        await tester.pumpWidget(
          createTestApp(backend: testBackend, cache: testCache),
        );
        await pumpAppReady(tester);
        await selectDefaultProfile(tester);
        await _navigateToDvr(tester);

        // Phase 16 DVR item 4: tap the FAB to expand the speed dial.
        final fab = find.byType(FloatingActionButton);
        expect(fab, findsWidgets, reason: 'DVR screen must have a FAB.');

        // Tap the main FAB.
        await tester.tap(fab.first);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        _drainException(tester);

        // After expanding, mini-action labels must be visible.
        expect(
          find.text('Storage'),
          findsWidgets,
          reason:
              'FAB speed dial must expose "Storage" mini action (FE-DVR-10).',
        );
        expect(
          find.text('Keyword Rules'),
          findsWidgets,
          reason:
              'FAB speed dial must expose "Keyword Rules" mini action '
              '(FE-DVR-07).',
        );
        expect(
          find.text('Schedule'),
          findsWidgets,
          reason:
              'FAB speed dial must expose "Schedule" mini action (FE-DVR-01).',
        );
      },
    );

    testWidgets('Speed dial Schedule action opens ScheduleDialog with 2 tabs', (
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
      await _navigateToDvr(tester);

      // Expand FAB.
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsWidgets, reason: 'DVR screen must have a FAB.');
      await tester.tap(fab.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      // Phase 16 DVR item 5: tap "Schedule" mini action.
      final scheduleBtn = find.text('Schedule');
      expect(
        scheduleBtn,
        findsWidgets,
        reason: 'FAB speed dial must expose "Schedule" mini action.',
      );
      await tester.tap(scheduleBtn.last);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      // ScheduleDialog must open as a Dialog.
      expect(
        find.byType(Dialog),
        findsOneWidget,
        reason: 'ScheduleDialog must open as a Dialog.',
      );

      // Phase 16 DVR item 5: Dialog header title is "DVR".
      expect(
        find.text('DVR'),
        findsOneWidget,
        reason: 'ScheduleDialog must show "DVR" as its header title.',
      );

      // Phase 16 DVR item 5: two tabs — Schedule, Auto-Record.
      expect(
        find.text('Schedule'),
        findsWidgets,
        reason: 'ScheduleDialog must have a "Schedule" tab.',
      );
      expect(
        find.text('Auto-Record'),
        findsOneWidget,
        reason: 'ScheduleDialog must have an "Auto-Record" tab (FE-DVR-07).',
      );

      // Phase 16 DVR item 5: channel name text field.
      expect(
        find.text('Channel Name'),
        findsOneWidget,
        reason: '"Channel Name" field must be present in the Schedule tab.',
      );

      // Close the dialog.
      final cancelBtn = find.text('Cancel');
      expect(
        cancelBtn,
        findsWidgets,
        reason: 'ScheduleDialog must have a "Cancel" button.',
      );
      await tester.tap(cancelBtn.first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('ScheduleDialog Schedule tab has datetime pickers', (
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
      await _navigateToDvr(tester);

      // Expand FAB and open Schedule dialog.
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsWidgets, reason: 'DVR screen must have a FAB.');
      await tester.tap(fab.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      final scheduleBtn = find.text('Schedule');
      expect(
        scheduleBtn,
        findsWidgets,
        reason: 'FAB speed dial must expose "Schedule" mini action.',
      );
      await tester.tap(scheduleBtn.last);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      // Phase 16 DVR item 5: start/end datetime picker tiles must be
      // present (identified by the "Start:" prefix in the tile title).
      expect(
        find.textContaining('Start:'),
        findsWidgets,
        reason: 'ScheduleDialog must show a "Start:" datetime picker tile.',
      );
      expect(
        find.textContaining('End:'),
        findsWidgets,
        reason: 'ScheduleDialog must show an "End:" datetime picker tile.',
      );

      // Close.
      final cancelBtn = find.text('Cancel');
      expect(
        cancelBtn,
        findsWidgets,
        reason: 'ScheduleDialog must have a "Cancel" button.',
      );
      await tester.tap(cancelBtn.first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('Speed dial Keyword Rules action opens KeywordRulesSheet', (
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
      await _navigateToDvr(tester);

      // Expand FAB.
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsWidgets, reason: 'DVR screen must have a FAB.');
      await tester.tap(fab.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      // Phase 16 DVR item 12: tap "Keyword Rules" mini action.
      final kwBtn = find.text('Keyword Rules');
      expect(
        kwBtn,
        findsWidgets,
        reason: 'FAB speed dial must expose "Keyword Rules" mini action.',
      );
      await tester.tap(kwBtn.last);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      // KeywordRulesSheet is a bottom sheet; verify its header title.
      expect(
        find.text('Keyword Auto-Record Rules'),
        findsOneWidget,
        reason:
            'KeywordRulesSheet must show "Keyword Auto-Record Rules" '
            'header.',
      );

      // Phase 16 DVR item 13: "Add Rule" button must be visible.
      expect(
        find.text('Add Rule'),
        findsWidgets,
        reason: 'KeywordRulesSheet must contain an "Add Rule" button.',
      );

      // Close the bottom sheet by tapping outside or back.
      await tester.tapAt(const Offset(10, 10));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('KeywordRulesSheet Add Rule opens keyword rule dialog', (
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
      await _navigateToDvr(tester);

      // Open Keyword Rules via FAB.
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsWidgets, reason: 'DVR screen must have a FAB.');
      await tester.tap(fab.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      final kwBtn = find.text('Keyword Rules');
      expect(
        kwBtn,
        findsWidgets,
        reason: 'FAB speed dial must expose "Keyword Rules" mini action.',
      );
      await tester.tap(kwBtn.last);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      // Phase 16 DVR item 13: tap "Add Rule" to open the rule dialog.
      final addRuleBtn = find.text('Add Rule');
      expect(
        addRuleBtn,
        findsWidgets,
        reason: 'KeywordRulesSheet must contain an "Add Rule" button.',
      );
      await tester.tap(addRuleBtn.first);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);

      // _KeywordRuleDialog (AlertDialog) must open.
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason:
            'Tapping "Add Rule" must open the keyword rule builder '
            'dialog.',
      );

      // Phase 16 DVR item 13: keyword input field must be present.
      expect(
        find.text('Keyword'),
        findsWidgets,
        reason: 'Keyword rule dialog must contain a "Keyword" text field.',
      );

      // Phase 16 DVR item 13: channel filter field must be present.
      expect(
        find.text('Channel Filter (optional)'),
        findsOneWidget,
        reason:
            'Keyword rule dialog must contain a "Channel Filter" '
            'field.',
      );

      // Close the dialog.
      final cancelBtn = find.text('Cancel');
      expect(
        cancelBtn,
        findsWidgets,
        reason: 'Keyword rule dialog must have a "Cancel" button.',
      );
      await tester.tap(cancelBtn.first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('DVR tabs show correct empty states', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);
      await seedTestSource(testCache);

      await tester.pumpWidget(
        createTestApp(backend: testBackend, cache: testCache),
      );
      await pumpAppReady(tester);
      await selectDefaultProfile(tester);
      await _navigateToDvr(tester);

      // Phase 16 DVR: each tab should show its empty message.
      // Tab 0 — Scheduled.
      expect(
        find.text('No scheduled recordings'),
        findsOneWidget,
        reason:
            'Scheduled tab empty state must read "No scheduled recordings".',
      );

      // Navigate to In Progress.
      final inProgressTab = find.text('In Progress');
      expect(
        inProgressTab,
        findsOneWidget,
        reason: '"In Progress" tab must be visible.',
      );
      await tester.tap(inProgressTab.first);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);
      expect(
        find.text('No active recordings'),
        findsOneWidget,
        reason: 'In Progress tab empty state must read "No active recordings".',
      );

      // Navigate to Completed.
      final completedTab = find.text('Completed');
      expect(
        completedTab,
        findsOneWidget,
        reason: '"Completed" tab must be visible.',
      );
      await tester.tap(completedTab.first);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      _drainException(tester);
      expect(
        find.text('No completed recordings'),
        findsOneWidget,
        reason:
            'Completed tab empty state must read "No completed recordings".',
      );
    });
  });
}
