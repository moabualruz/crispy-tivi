import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/parental/data/parental_service.dart';
import 'package:crispy_tivi/features/parental/domain/content_rating.dart';
import 'package:crispy_tivi/features/profiles/data/profile_service.dart';
import 'package:crispy_tivi/features/profiles/domain/entities/user_profile.dart';
import 'package:crispy_tivi/features/settings/presentation/providers/'
    'pin_lockout_provider.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'parental_settings.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';

// ── Fake ParentalService ──────────────────────────────────────

class _FakeParentalService extends ParentalService {
  bool _hasMasterPin;
  String? lastSetPin;
  String? lastVerifiedPin;
  String? lastClearedPin;

  _FakeParentalService({bool hasMasterPin = false})
    : _hasMasterPin = hasMasterPin;

  @override
  Future<ParentalState> build() async =>
      ParentalState(hasMasterPin: _hasMasterPin);

  @override
  Future<void> setMasterPin(String pin) async {
    lastSetPin = pin;
    _hasMasterPin = true;
    state = AsyncData(ParentalState(hasMasterPin: true, isUnlocked: true));
  }

  @override
  Future<bool> verifyMasterPin(String pin) async {
    lastVerifiedPin = pin;
    // In tests the correct PIN is always '1234'.
    return pin == '1234';
  }

  @override
  Future<bool> clearMasterPin(String currentPin) async {
    lastClearedPin = currentPin;
    if (currentPin != '1234') return false;
    _hasMasterPin = false;
    state = AsyncData(const ParentalState(hasMasterPin: false));
    return true;
  }
}

// ── Fake ProfileService ───────────────────────────────────────

class _FakeProfileService extends ProfileService {
  final List<UserProfile> _profiles;
  String? lastUpdatedProfileId;
  bool? lastIsChild;
  int? lastMaxAllowedRating;

  _FakeProfileService({List<UserProfile>? profiles})
    : _profiles = profiles ?? [];

  @override
  Future<ProfileState> build() async => ProfileState(
    profiles: _profiles,
    activeProfileId: _profiles.isEmpty ? 'default' : _profiles.first.id,
  );

  @override
  Future<void> updateProfile(
    String id, {
    String? name,
    int? avatarIndex,
    String? pin,
    bool? isChild,
    int? maxAllowedRating,
    dynamic role,
    dynamic dvrPermission,
    int? dvrQuotaMB,
    int? accentColorValue,
    String? preferredAudioLanguage,
    String? preferredSubtitleLanguage,
    bool? subtitleEnabledByDefault,
    bool clearPin = false,
    bool clearDvrQuota = false,
    bool clearAccentColor = false,
    bool clearAudioLanguage = false,
    bool clearSubtitleLanguage = false,
  }) async {
    lastUpdatedProfileId = id;
    lastIsChild = isChild;
    lastMaxAllowedRating = maxAllowedRating;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Sample profiles ───────────────────────────────────────────

const _adultProfile = UserProfile(
  id: 'adult-1',
  name: 'Alice',
  avatarIndex: 0,
  isChild: false,
  maxAllowedRating: 4,
);

const _childProfile = UserProfile(
  id: 'child-1',
  name: 'Bob',
  avatarIndex: 1,
  isChild: true,
  maxAllowedRating: 1,
);

// ── Test helpers ──────────────────────────────────────────────

/// Pumps [ParentalSettingsSection] with provider overrides.
Future<void> _pump(
  WidgetTester tester, {
  required _FakeParentalService fakeParental,
  required _FakeProfileService fakeProfile,
}) async {
  final backend = MemoryBackend();
  final cache = CacheService(backend);
  final key = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        crispyBackendProvider.overrideWithValue(backend),
        cacheServiceProvider.overrideWithValue(cache),
        parentalServiceProvider.overrideWith(() => fakeParental),
        profileServiceProvider.overrideWith(() => fakeProfile),
      ],
      child: MaterialApp(
        key: key,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: ParentalSettingsSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Eagerly trigger profileServiceProvider build so it's in AsyncData
  // when Profile Restrictions dialog reads it synchronously.
  ProviderScope.containerOf(key.currentContext!).read(profileServiceProvider);
  await tester.pumpAndSettle();
}

/// Pumps the widget and returns a [ProviderContainer] for lockout tests
/// that need to interact with the lockout notifier.
Future<ProviderContainer> _pumpForLockout(
  WidgetTester tester, {
  required _FakeParentalService fakeParental,
  required _FakeProfileService fakeProfile,
}) async {
  final backend = MemoryBackend();
  final cache = CacheService(backend);
  final key = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        crispyBackendProvider.overrideWithValue(backend),
        cacheServiceProvider.overrideWithValue(cache),
        parentalServiceProvider.overrideWith(() => fakeParental),
        profileServiceProvider.overrideWith(() => fakeProfile),
      ],
      child: MaterialApp(
        key: key,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: ParentalSettingsSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(key.currentContext!);
}

// ── Tests ─────────────────────────────────────────────────────

void main() {
  // ── PIN — no PIN set ────────────────────────────────────────

  group('PIN — no PIN set', () {
    late _FakeParentalService fakeParental;
    late _FakeProfileService fakeProfile;

    setUp(() {
      fakeParental = _FakeParentalService(hasMasterPin: false);
      fakeProfile = _FakeProfileService();
    });

    testWidgets('shows "No PIN set" subtitle when no PIN is configured', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      expect(find.text('No PIN set'), findsOneWidget);
    });

    testWidgets('shows "Master PIN" tile title', (tester) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      expect(find.text('Master PIN'), findsOneWidget);
    });

    testWidgets(
      'tapping Master PIN tile opens PinInputDialog in confirm mode',
      (tester) async {
        await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Master PIN'));
        await tester.pumpAndSettle();

        // PinInputDialog is shown in confirm (set-new-PIN) mode.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Set Master PIN'), findsOneWidget);
      },
    );

    testWidgets('Set Master PIN dialog contains 4 digit TextField fields', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      // 4 PIN digit TextFields are rendered.
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('Cancel button closes the Set Master PIN dialog', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Set Master PIN dialog subtitle describes its purpose', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      // The subtitle is rendered in the dialog content.
      expect(find.textContaining('parental control'), findsOneWidget);
    });
  });

  // ── PIN — PIN already set ───────────────────────────────────

  group('PIN — PIN already set', () {
    late _FakeParentalService fakeParental;
    late _FakeProfileService fakeProfile;

    setUp(() {
      fakeParental = _FakeParentalService(hasMasterPin: true);
      fakeProfile = _FakeProfileService();
    });

    testWidgets('shows "PIN is set" subtitle when PIN is configured', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      expect(find.text('PIN is set'), findsOneWidget);
    });

    testWidgets('tapping Master PIN tile opens action AlertDialog', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('action dialog shows Change PIN option', (tester) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Change PIN'), findsOneWidget);
    });

    testWidgets('action dialog shows Remove PIN option', (tester) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Remove PIN'), findsOneWidget);
    });

    testWidgets('action dialog shows Cancel option', (tester) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('tapping Cancel in action dialog closes it without action', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fakeParental.lastSetPin, isNull);
      expect(fakeParental.lastClearedPin, isNull);
    });

    testWidgets('tapping Change PIN opens Enter Current PIN dialog', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change PIN'));
      await tester.pumpAndSettle();

      // PinInputDialog in verify mode opens with "Enter Current PIN" title.
      expect(find.text('Enter Current PIN'), findsOneWidget);
    });

    testWidgets(
      'Enter Current PIN dialog for Change shows verification subtitle',
      (tester) async {
        await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Master PIN'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Change PIN'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Verify your current PIN'), findsOneWidget);
      },
    );

    testWidgets('tapping Remove PIN opens Enter Current PIN dialog', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Current PIN'), findsOneWidget);
    });

    testWidgets(
      'Enter Current PIN dialog for Remove shows clear-PIN subtitle',
      (tester) async {
        await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Master PIN'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove PIN'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Verify your PIN to remove it'),
          findsOneWidget,
        );
      },
    );
  });

  // ── PIN lockout ─────────────────────────────────────────────

  group('PIN lockout', () {
    late _FakeParentalService fakeParental;
    late _FakeProfileService fakeProfile;

    setUp(() {
      fakeParental = _FakeParentalService(hasMasterPin: false);
      fakeProfile = _FakeProfileService();
    });

    /// Opens the PIN dialog and fires [kPinMaxAttempts] wrong attempts
    /// via the provider notifier to trigger a lockout.
    Future<void> triggerLockout(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      final notifier = container.read(pinLockoutProvider.notifier);
      for (var i = 0; i < kPinMaxAttempts; i++) {
        notifier.recordFailure(profileId: '__global__');
      }
      await tester.pump(); // let the notifier update state.
    }

    /// Cancels any active lockout timer to prevent pumpAndSettle hangs
    /// in teardown.
    void cancelLockout(ProviderContainer container) {
      container
          .read(pinLockoutProvider.notifier)
          .recordSuccess(profileId: '__global__');
    }

    testWidgets(
      'lockout message visible in PIN dialog after max failed attempts',
      (tester) async {
        final container = await _pumpForLockout(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        // Open the PIN dialog. Use pump() because lockout creates
        // Timer.periodic that prevents pumpAndSettle from settling.
        await tester.tap(find.text('Master PIN'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(AlertDialog), findsOneWidget);

        await triggerLockout(tester, container);
        await tester.pump();

        expect(find.text('Too many incorrect attempts.'), findsOneWidget);

        cancelLockout(container);
      },
    );

    testWidgets(
      'countdown text appears in PIN dialog after lockout is triggered',
      (tester) async {
        final container = await _pumpForLockout(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Master PIN'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await triggerLockout(tester, container);
        await tester.pump();

        expect(find.textContaining('Try again in'), findsOneWidget);

        cancelLockout(container);
      },
    );

    testWidgets('lock_clock icon is shown in PIN dialog when locked', (
      tester,
    ) async {
      final container = await _pumpForLockout(
        tester,
        fakeParental: fakeParental,
        fakeProfile: fakeProfile,
      );

      await tester.tap(find.text('Master PIN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await triggerLockout(tester, container);
      await tester.pump();

      expect(find.byIcon(Icons.lock_clock), findsOneWidget);

      cancelLockout(container);
    });

    testWidgets('Submit button is absent from PIN dialog when locked', (
      tester,
    ) async {
      final container = await _pumpForLockout(
        tester,
        fakeParental: fakeParental,
        fakeProfile: fakeProfile,
      );

      await tester.tap(find.text('Master PIN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await triggerLockout(tester, container);
      await tester.pump();

      // PinInputDialog hides FilledButton ("Submit") when locked.
      expect(find.byType(FilledButton), findsNothing);

      cancelLockout(container);
    });

    testWidgets(
      'PIN fields are disabled (not rendered) when lockout is active',
      (tester) async {
        final container = await _pumpForLockout(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Master PIN'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await triggerLockout(tester, container);
        await tester.pump();

        // When locked, PinInputDialog hides the digit TextField widgets.
        expect(find.byType(TextField), findsNothing);

        cancelLockout(container);
      },
    );
  });

  // ── Profile Restrictions ─────────────────────────────────────

  group('Profile Restrictions', () {
    late _FakeParentalService fakeParental;
    late _FakeProfileService fakeProfile;

    setUp(() {
      fakeParental = _FakeParentalService(hasMasterPin: true);
      fakeProfile = _FakeProfileService(
        profiles: [_adultProfile, _childProfile],
      );
    });

    testWidgets(
      'Profile Restrictions tile is present when parental state is loaded',
      (tester) async {
        await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        expect(find.text('Profile Restrictions'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Profile Restrictions tile opens the restrictions dialog',
      (tester) async {
        await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Profile Restrictions'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        // The title appears twice: tile + dialog header.
        expect(find.text('Profile Restrictions'), findsNWidgets(2));
      },
    );

    testWidgets('restrictions dialog shows profile names', (tester) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Profile Restrictions'));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('dialog renders one isChild Switch per profile', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Profile Restrictions'));
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNWidgets(2));
    });

    testWidgets('isChild Switch is checked for the child profile (Bob)', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Profile Restrictions'));
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      // Bob is isChild = true → second Switch should be on.
      expect(switches[1].value, isTrue);
    });

    testWidgets('isChild Switch is unchecked for the adult profile (Alice)', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Profile Restrictions'));
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      // Alice is isChild = false → first Switch should be off.
      expect(switches[0].value, isFalse);
    });

    testWidgets('dialog renders one DropdownButton per profile', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Profile Restrictions'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButton<int>), findsNWidgets(2));
    });

    testWidgets(
      'NC-17 rating code is shown for the adult profile (Alice, rating=4)',
      (tester) async {
        await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Profile Restrictions'));
        await tester.pumpAndSettle();

        // NC-17 (value=4) is Alice's maxAllowedRating.
        expect(find.text(ContentRatingLevel.nc17.code), findsOneWidget);
      },
    );

    testWidgets(
      'PG rating code is shown for the child profile (Bob, rating=1)',
      (tester) async {
        await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Profile Restrictions'));
        await tester.pumpAndSettle();

        // PG (value=1) is Bob's maxAllowedRating.
        expect(find.text(ContentRatingLevel.pg.code), findsOneWidget);
      },
    );

    testWidgets(
      'Cancel button closes the dialog without calling updateProfile',
      (tester) async {
        await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Profile Restrictions'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(fakeProfile.lastUpdatedProfileId, isNull);
      },
    );

    testWidgets('Save button is present in the restrictions dialog', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Profile Restrictions'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('"Restricted" badge visible for the child profile (Bob)', (
      tester,
    ) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Profile Restrictions'));
      await tester.pumpAndSettle();

      // Bob has isChild=true and maxAllowedRating=1 < 4 → shows "Restricted".
      expect(find.text('Restricted'), findsOneWidget);
    });

    testWidgets(
      'tapping Save calls updateProfile for profiles whose values changed',
      (tester) async {
        await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Profile Restrictions'));
        await tester.pumpAndSettle();

        // Toggle Alice's isChild switch to true (was false).
        final aliceSwitch = find.byType(Switch).first;
        await tester.tap(aliceSwitch);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // updateProfile should have been called for Alice (id: 'adult-1').
        expect(fakeProfile.lastUpdatedProfileId, 'adult-1');
        expect(fakeProfile.lastIsChild, isTrue);
      },
    );

    testWidgets('dialog closes after tapping Save', (tester) async {
      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      await tester.tap(find.text('Profile Restrictions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
      'shows "No profiles found" snackbar when profile list is empty',
      (tester) async {
        final emptyProfile = _FakeProfileService(profiles: []);

        await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: emptyProfile,
        );

        await tester.tap(find.text('Profile Restrictions'));
        await tester.pumpAndSettle();

        // No dialog opened — snackbar shown instead.
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('No profiles found'), findsOneWidget);
      },
    );
  });

  // ── Section header ────────────────────────────────────────────

  group('Section header', () {
    testWidgets('renders "Parental Controls" section header', (tester) async {
      final fakeParental = _FakeParentalService();
      final fakeProfile = _FakeProfileService();

      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      expect(find.text('Parental Controls'), findsOneWidget);
    });

    testWidgets('renders family_restroom icon in section header', (
      tester,
    ) async {
      final fakeParental = _FakeParentalService();
      final fakeProfile = _FakeProfileService();

      await _pump(tester, fakeParental: fakeParental, fakeProfile: fakeProfile);

      expect(find.byIcon(Icons.family_restroom), findsOneWidget);
    });
  });
}
