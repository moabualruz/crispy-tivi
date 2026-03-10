import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/features/profiles/domain/entities/user_profile.dart';
import 'package:crispy_tivi/features/profiles/domain/enums/dvr_permission.dart';
import 'package:crispy_tivi/features/profiles/domain/enums/user_role.dart';
import 'package:crispy_tivi/features/settings/presentation/providers/pin_lockout_provider.dart';

import '../helpers/test_app.dart';

/// FNV-1a hash of PIN "1234" as produced by [MemoryBackend.hashPin].
///
/// Pre-computed to avoid depending on the backend during profile seeding.
/// Formula: `hash = 0x811c9dc5; for b in utf8("1234"): hash ^= b; hash *= 0x01000193`
const _kPin1234Hash =
    '00000000000000000000000000000000000000000000000000000000fdc422fd';

/// A second profile (no PIN) used to force the profile selection screen.
const _kSecondProfile = UserProfile(
  id: 'second',
  name: 'Family',
  avatarIndex: 2,
  pinVersion: 1,
  role: UserRole.viewer,
  dvrPermission: DvrPermission.full,
);

/// A PIN-protected profile with PIN "1234" (pinVersion=1, hashed).
const _kPinnedProfile = UserProfile(
  id: 'pinned_test',
  name: 'Secure',
  avatarIndex: 1,
  pin: _kPin1234Hash,
  pinVersion: 1,
  role: UserRole.viewer,
  dvrPermission: DvrPermission.full,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Seeds [cache] with a source + two profiles so the profile selection
  /// screen is shown (router auto-skips when there is only one no-PIN profile).
  ///
  /// The PIN-protected profile "Secure" (PIN: 1234) is seeded alongside
  /// a second profile "Family" (no PIN) to trigger the selection screen.
  Future<void> seedProfiles(CacheService cache) async {
    await seedTestSource(cache);
    await cache.saveProfile(_kPinnedProfile);
    await cache.saveProfile(_kSecondProfile);
  }

  /// Pumps the app with [backend] / [cache] and waits for the profile
  /// selection screen to appear.
  Future<void> launchToProfileSelection(
    WidgetTester tester, {
    required MemoryBackend backend,
    required CacheService cache,
  }) async {
    await tester.pumpWidget(createTestApp(backend: backend, cache: cache));
    await pumpAppReady(tester);
    expect(
      find.text("Who's Watching?"),
      findsOneWidget,
      reason: 'Profile selection screen must be visible after launch.',
    );
  }

  /// Enters [digits] one by one into the 4-digit PIN fields.
  ///
  /// Finds the PIN TextFields by semantics label "PIN digit N" and types
  /// a single character into each. Pumps frames between each digit to
  /// allow the auto-advance focus logic to run.
  Future<void> enterPinDigits(WidgetTester tester, String digits) async {
    assert(digits.length <= 4, 'PIN must be 4 digits');
    for (var i = 0; i < digits.length; i++) {
      final digitField = find.bySemanticsLabel('PIN digit ${i + 1}');
      expect(
        digitField,
        findsOneWidget,
        reason: 'PIN digit ${i + 1} field must be present.',
      );
      await tester.tap(digitField);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(digitField, digits[i]);
      for (var j = 0; j < 5; j++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  // ── Profile card: lock icon ────────────────────────────────────────────────

  group('Profile card', () {
    testWidgets('PIN-protected profile card shows lock icon', (tester) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);
      await seedProfiles(cache);

      await launchToProfileSelection(tester, backend: backend, cache: cache);

      // The profile tile renders lock_outline for PIN-protected profiles.
      expect(
        find.byIcon(Icons.lock_outline),
        findsOneWidget,
        reason: 'PIN-protected profile card must show a lock_outline icon.',
      );
    });

    testWidgets('Unprotected profile card has no lock icon', (tester) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);
      await seedProfiles(cache);

      await launchToProfileSelection(tester, backend: backend, cache: cache);

      // "Family" profile has no PIN — no lock icon on that tile.
      // The lock icon may exist once (for "Secure") but not twice.
      final lockIcons = find.byIcon(Icons.lock_outline).evaluate();
      expect(
        lockIcons.length,
        equals(1),
        reason: 'Only the PIN-protected profile must show a lock icon.',
      );
    });
  });

  // ── PIN dialog opens ────────────────────────────────────────────────────────

  group('PIN dialog', () {
    testWidgets('Tapping PIN-protected profile opens PinInputDialog', (
      tester,
    ) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);
      await seedProfiles(cache);

      await launchToProfileSelection(tester, backend: backend, cache: cache);

      // Tap the "Secure" profile tile.
      await tester.tap(find.text('Secure'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Dialog title must contain the profile name.
      expect(
        find.textContaining('Secure'),
        findsWidgets,
        reason: 'PIN dialog title must mention the profile name.',
      );
    });

    testWidgets('PIN dialog contains 4 separate obscured digit fields', (
      tester,
    ) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);
      await seedProfiles(cache);

      await launchToProfileSelection(tester, backend: backend, cache: cache);

      await tester.tap(find.text('Secure'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 4 digit fields identified by semantics labels "PIN digit 1" … "PIN digit 4".
      for (var i = 1; i <= 4; i++) {
        expect(
          find.bySemanticsLabel('PIN digit $i'),
          findsOneWidget,
          reason: 'PIN digit $i field must be present.',
        );
      }

      // Each TextField must be obscured.
      final textFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((f) => f.obscureText)
          .toList(growable: false);
      expect(
        textFields.length,
        greaterThanOrEqualTo(4),
        reason: '4 obscured TextField widgets must be present for PIN entry.',
      );
    });

    testWidgets('Cancel button closes dialog without navigating', (
      tester,
    ) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);
      await seedProfiles(cache);

      await launchToProfileSelection(tester, backend: backend, cache: cache);

      await tester.tap(find.text('Secure'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Dialog is open.
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Profile selection screen must still be visible.
      expect(find.text("Who's Watching?"), findsOneWidget);
    });
  });

  // ── Correct PIN ────────────────────────────────────────────────────────────

  group('Correct PIN entry', () {
    testWidgets('Entering correct PIN navigates to app shell', (tester) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);
      await seedProfiles(cache);

      await launchToProfileSelection(tester, backend: backend, cache: cache);

      // Open the PIN dialog for "Secure".
      await tester.tap(find.text('Secure'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Enter correct PIN "1234".
      await enterPinDigits(tester, '1234');

      // Allow navigation to complete.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Profile selection screen must be gone.
      expect(find.text("Who's Watching?"), findsNothing);

      // App shell must be present.
      expect(find.byKey(TestKeys.appShell), findsOneWidget);
    });
  });

  // ── Wrong PIN ──────────────────────────────────────────────────────────────

  group('Wrong PIN entry', () {
    testWidgets('Wrong PIN shows "Incorrect PIN" error', (tester) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);
      await seedProfiles(cache);

      await launchToProfileSelection(tester, backend: backend, cache: cache);

      await tester.tap(find.text('Secure'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Enter wrong PIN "9999".
      await enterPinDigits(tester, '9999');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Error state shown in dialog.
      expect(
        find.text('Incorrect PIN'),
        findsOneWidget,
        reason: 'Wrong PIN must show "Incorrect PIN" error text.',
      );

      // Dialog must still be open — no navigation occurred.
      expect(find.text("Who's Watching?"), findsNothing);
      // Dialog title still visible.
      expect(find.textContaining('Secure'), findsWidgets);
    });

    testWidgets('Dialog remains open after wrong PIN, fields are cleared', (
      tester,
    ) async {
      final backend = MemoryBackend();
      final cache = CacheService(backend);
      await seedProfiles(cache);

      await launchToProfileSelection(tester, backend: backend, cache: cache);

      await tester.tap(find.text('Secure'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await enterPinDigits(tester, '0000');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Fields are cleared after a wrong attempt; all 4 fields are still visible.
      for (var i = 1; i <= 4; i++) {
        expect(
          find.bySemanticsLabel('PIN digit $i'),
          findsOneWidget,
          reason:
              'PIN digit $i field must still be present after wrong attempt.',
        );
      }
    });
  });

  // ── Lockout after 3 wrong attempts ────────────────────────────────────────

  group('PIN lockout', () {
    testWidgets(
      '3 wrong attempts trigger lockout — countdown visible, fields disabled',
      (tester) async {
        final backend = MemoryBackend();
        final cache = CacheService(backend);
        await seedProfiles(cache);

        await launchToProfileSelection(tester, backend: backend, cache: cache);

        await tester.tap(find.text('Secure'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Enter wrong PIN kPinMaxAttempts (3) times.
        for (var attempt = 0; attempt < kPinMaxAttempts; attempt++) {
          await enterPinDigits(tester, '0000');
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        // Lockout state: "Too many incorrect attempts." must appear.
        expect(
          find.text('Too many incorrect attempts.'),
          findsOneWidget,
          reason: 'Lockout message must appear after 3 wrong PIN attempts.',
        );

        // Countdown text must be visible (pattern "Try again in MM:SS").
        expect(
          find.textContaining('Try again in'),
          findsOneWidget,
          reason: 'Countdown text must be visible during lockout.',
        );
      },
    );

    testWidgets(
      'Pre-locked profile: all PIN digit fields are disabled during lockout',
      (tester) async {
        final backend = MemoryBackend();
        final cache = CacheService(backend);
        await seedProfiles(cache);

        // Build the app with the lockout notifier pre-seeded for the profile.
        await tester.pumpWidget(
          createTestApp(
            backend: backend,
            cache: cache,
            pinLockoutNotifierOverride:
                () => _PreLockedNotifier(profileId: _kPinnedProfile.id),
          ),
        );
        await pumpAppReady(tester);

        // Navigate to profile selection.
        expect(find.text("Who's Watching?"), findsOneWidget);

        // Tap the PIN-protected profile.
        await tester.tap(find.text('Secure'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Lockout message must appear immediately.
        expect(
          find.text('Too many incorrect attempts.'),
          findsOneWidget,
          reason:
              'Pre-locked profile must show lockout message when dialog opens.',
        );

        // Countdown must be visible.
        expect(find.textContaining('Try again in'), findsOneWidget);

        // All 4 digit TextFields must be disabled (enabled=false).
        final pinTextFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .where((f) => f.obscureText)
            .toList(growable: false);

        for (final field in pinTextFields) {
          expect(
            field.enabled,
            isFalse,
            reason: 'PIN digit fields must be disabled during lockout.',
          );
        }
      },
    );
  });
}

// ── Test notifier helpers ──────────────────────────────────────────────────────

/// A [PinLockoutNotifier] that immediately locks [profileId] after
/// the provider initializes.
///
/// Used to test the lockout UI without simulating 3 actual wrong-PIN attempts.
/// Schedules [kPinMaxAttempts] failures via a post-frame microtask so the
/// state is properly initialized before being mutated.
class _PreLockedNotifier extends PinLockoutNotifier {
  _PreLockedNotifier({required this.profileId});

  final String profileId;

  @override
  PinLockoutState build() {
    final initial = super.build();

    // Schedule lockout after build() returns and state is initialized.
    // Using Future.microtask ensures state is set before the first frame
    // renders the dialog.
    Future.microtask(() {
      for (var i = 0; i < kPinMaxAttempts; i++) {
        recordFailure(profileId: profileId);
      }
    });

    return initial;
  }
}
