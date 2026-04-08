import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/features/onboarding/presentation/providers/onboarding_notifier.dart';
import 'package:crispy_tivi/features/onboarding/presentation/widgets/onboarding_step_indicator.dart';
import 'package:crispy_tivi/features/onboarding/presentation/widgets/onboarding_type_picker_step.dart';

import '../helpers/test_app.dart';

/// Pumps frames until [finder] matches at least one widget or [maxMs]
/// elapses. Never calls pumpAndSettle.
Future<void> pumpUntilFound(
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Shared helpers ─────────────────────────────────────────────────────────

  /// Pumps the test app with a fresh, source-less [MemoryBackend].
  /// The router guard redirects to /onboarding when no sources are seeded.
  Future<void> launchEmpty(WidgetTester tester) async {
    final backend = MemoryBackend();
    final cache = CacheService(backend);
    await tester.pumpWidget(createTestApp(backend: backend, cache: cache));
    await pumpAppReady(tester);
  }

  /// Taps "Start Watching" and waits for the PageView animation.
  Future<void> tapStartWatching(WidgetTester tester) async {
    final btn = find.text('Start Watching');
    expect(btn, findsOneWidget);
    await tester.tap(btn);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // ── Step 1: Welcome ────────────────────────────────────────────────────────

  group('Welcome step', () {
    testWidgets('Empty backend redirects to onboarding screen', (tester) async {
      await launchEmpty(tester);

      // Router guard must redirect to /onboarding when no sources exist.
      expect(find.byKey(TestKeys.onboardingScreen), findsOneWidget);
    });

    testWidgets('Shows "Start Watching" primary CTA button', (tester) async {
      await launchEmpty(tester);

      expect(find.text('Start Watching'), findsOneWidget);
    });

    testWidgets('Step indicator shows 3 dots, first dot active', (
      tester,
    ) async {
      await launchEmpty(tester);

      expect(find.byKey(TestKeys.onboardingStepIndicator), findsOneWidget);
      expect(find.byType(OnboardingStepIndicator), findsOneWidget);

      // Semantics announce "Step 1 of 3" on Welcome.
      expect(
        find.bySemanticsLabel('Step 1 of 3'),
        findsOneWidget,
        reason: 'Indicator must announce "Step 1 of 3" on Welcome step.',
      );
    });

    testWidgets('No skip or dismiss button is present', (tester) async {
      await launchEmpty(tester);

      // Spec explicitly forbids a skip option.
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);
      expect(find.text('Close'), findsNothing);
    });
  });

  // ── Step 2: Type Picker ────────────────────────────────────────────────────

  group('TypePicker step', () {
    testWidgets('"Start Watching" advances to TypePicker', (tester) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      expect(find.byType(OnboardingTypePickerStep), findsOneWidget);
    });

    testWidgets('Shows 3 source-type cards: M3U, Xtream, Stalker', (
      tester,
    ) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      expect(
        find.byKey(TestKeys.onboardingSourceType('m3u')),
        findsOneWidget,
        reason: 'M3U source-type card must be present.',
      );
      expect(
        find.byKey(TestKeys.onboardingSourceType('xtream')),
        findsOneWidget,
        reason: 'Xtream source-type card must be present.',
      );
      expect(
        find.byKey(TestKeys.onboardingSourceType('stalker')),
        findsOneWidget,
        reason: 'Stalker source-type card must be present.',
      );
    });

    testWidgets('Step indicator advances to dot 2 of 3', (tester) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      expect(
        find.bySemanticsLabel('Step 2 of 3'),
        findsOneWidget,
        reason: 'Indicator must announce "Step 2 of 3" on TypePicker.',
      );
    });

    testWidgets('No skip button on TypePicker step', (tester) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      expect(find.text('Skip'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);
    });
  });

  // ── Step 3: Form field variants ────────────────────────────────────────────

  group('Form step — M3U', () {
    testWidgets('Shows Name and Playlist URL fields only', (tester) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      await tester.tap(find.byKey(TestKeys.onboardingSourceType('m3u')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Playlist URL'), findsOneWidget);
      expect(find.text('Username'), findsNothing);
      expect(find.text('Password'), findsNothing);
      expect(find.text('MAC Address'), findsNothing);
    });
  });

  group('Form step — Xtream', () {
    testWidgets('Shows Name, Server URL, Username, Password', (tester) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      await tester.tap(find.byKey(TestKeys.onboardingSourceType('xtream')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('MAC Address'), findsNothing);
    });
  });

  group('Form step — Stalker', () {
    testWidgets('Shows Name, Portal URL, and MAC Address', (tester) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      await tester.tap(find.byKey(TestKeys.onboardingSourceType('stalker')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Portal URL'), findsOneWidget);
      expect(find.text('MAC Address'), findsOneWidget);
      expect(find.text('Username'), findsNothing);
      expect(find.text('Password'), findsNothing);
    });
  });

  // ── Validation ─────────────────────────────────────────────────────────────

  group('Form validation', () {
    testWidgets('M3U: empty URL shows "URL is required." error', (
      tester,
    ) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      await tester.tap(find.byKey(TestKeys.onboardingSourceType('m3u')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Leave fields empty and tap Connect.
      await tester.tap(find.text('Connect'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('URL is required.'), findsOneWidget);
      // No sync progress — wizard must not advance.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Xtream: URL present but no credentials shows error', (
      tester,
    ) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      await tester.tap(find.byKey(TestKeys.onboardingSourceType('xtream')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final urlField = find.widgetWithText(TextField, 'Server URL');
      await tester.enterText(urlField, 'http://test.example.com:8080');
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Connect'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Username and password are required.'), findsOneWidget);
    });

    testWidgets('Stalker: invalid MAC format shows error message', (
      tester,
    ) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      await tester.tap(find.byKey(TestKeys.onboardingSourceType('stalker')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tester.enterText(
        find.widgetWithText(TextField, 'Portal URL'),
        'http://portal.example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'MAC Address'),
        'BADMAC',
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Connect'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        find.text('Invalid MAC address format. Use XX:XX:XX:XX:XX:XX.'),
        findsOneWidget,
      );
    });
  });

  // ── Step 4: Sync — success via MemoryBackend ───────────────────────────────

  group('Sync step — success', () {
    testWidgets('Valid M3U submit: success state shows check icon', (
      tester,
    ) async {
      await launchEmpty(tester);
      await tapStartWatching(tester);

      await tester.tap(find.byKey(TestKeys.onboardingSourceType('m3u')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // MemoryBackend.verifyM3uUrl returns true and syncM3uSource returns
      // a 0-channel success response, so this triggers SyncStatus.success.
      await tester.enterText(
        find.widgetWithText(TextField, 'Playlist URL'),
        'http://test.iptv.com/playlist.m3u',
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Connect'));

      // Allow time for verify + sync to complete.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Success: check_circle icon appears.
      expect(
        find.byIcon(Icons.check_circle),
        findsOneWidget,
        reason: 'Sync success must show check_circle icon.',
      );
      // "Enter App" CTA must be visible.
      expect(find.text('Enter App'), findsOneWidget);
    });
  });

  // ── Step 4: Sync — error via notifier override ─────────────────────────────

  group('Sync step — error', () {
    testWidgets('Error state shows error_outline icon and retry/edit buttons', (
      tester,
    ) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);

      // Launch with the notifier pre-seeded in error state so we verify
      // the error UI without relying on actual network failure.
      await tester.pumpWidget(
        createTestApp(
          backend: backend,
          cache: cache,
          onboardingNotifierOverride: _ErrorStateOnboardingNotifier.new,
        ),
      );
      await pumpAppReady(tester);

      // Onboarding screen is visible (notifier starts at syncing step).
      expect(find.byKey(TestKeys.onboardingScreen), findsOneWidget);

      // The PageView must advance to the syncing page (index 3).
      // Wait a bit more for the PageController to animate.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Error state: error_outline icon must be shown.
      expect(
        find.byIcon(Icons.error_outline),
        findsOneWidget,
        reason: 'Error sync state must display error_outline icon.',
      );

      // Retry button — uses commonRetry l10n ("Retry").
      final hasRetry =
          find.text('Retry').evaluate().isNotEmpty ||
          find.bySemanticsLabel('Retry connection').evaluate().isNotEmpty;
      expect(hasRetry, isTrue, reason: 'Retry button must be visible.');

      // Edit source button — uses onboardingEditSource l10n.
      final hasEdit =
          find.text('Edit source details').evaluate().isNotEmpty ||
          find.bySemanticsLabel('Edit source details').evaluate().isNotEmpty;
      expect(
        hasEdit,
        isTrue,
        reason: 'Edit source details button must be visible.',
      );
    });
  });

  // ── Router guard ───────────────────────────────────────────────────────────

  group('Router guard', () {
    testWidgets('Seeded source skips onboarding', (tester) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);
      await seedTestSource(cache);

      await tester.pumpWidget(createTestApp(backend: backend, cache: cache));
      await pumpAppReady(tester);

      // Router guard must NOT redirect to onboarding when a source exists.
      expect(find.byKey(TestKeys.onboardingScreen), findsNothing);
    });
  });
}

// ── Test notifier helpers ──────────────────────────────────────────────────────

/// An [OnboardingNotifier] pre-seeded in the error sync state.
///
/// Starts at [OnboardingStep.syncing] with [SyncStatus.error] so the
/// OnboardingSyncStep renders the error UI without triggering real network
/// calls.
class _ErrorStateOnboardingNotifier extends OnboardingNotifier {
  @override
  OnboardingState build() {
    return const OnboardingState(
      step: OnboardingStep.syncing,
      syncStatus: SyncStatus.error,
      syncErrorMessage: 'Simulated connection failure',
    );
  }
}
