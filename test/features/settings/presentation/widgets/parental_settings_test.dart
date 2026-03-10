import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _FakeParentalService extends AsyncNotifier<ParentalState>
    implements ParentalService {
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

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Fake ProfileService ───────────────────────────────────────

class _FakeProfileService extends AsyncNotifier<ProfileState>
    implements ProfileService {
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
///
/// Returns the [ProviderContainer] so callers can interact with
/// [pinLockoutProvider] to simulate lockout.
///
/// Both [parentalServiceProvider] and [profileServiceProvider] are
/// pre-warmed (read once) before the widget pump so that
/// [ref.read] inside tap handlers returns [AsyncData] immediately.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _FakeParentalService fakeParental,
  required _FakeProfileService fakeProfile,
}) async {
  final container = ProviderContainer(
    overrides: [
      parentalServiceProvider.overrideWith(() => fakeParental),
      profileServiceProvider.overrideWith(() => fakeProfile),
    ],
  );
  addTearDown(container.dispose);

  // Pre-warm async providers so their state is AsyncData before any tap.
  container.read(parentalServiceProvider);
  container.read(profileServiceProvider);
  // Allow futures from async build() methods to complete.
  await Future<void>.delayed(Duration.zero);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: ParentalSettingsSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
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
      // Drive the lockout through the public notifier API.
      final notifier = container.read(pinLockoutProvider.notifier);
      for (var i = 0; i < kPinMaxAttempts; i++) {
        notifier.recordFailure(profileId: '__global__');
      }
      await tester.pump(); // let the notifier update state.
    }

    testWidgets(
      'lockout message visible in PIN dialog after max failed attempts',
      (tester) async {
        final container = await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        // Open the PIN dialog.
        await tester.tap(find.text('Master PIN'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        // Trigger lockout via the real notifier.
        await triggerLockout(tester, container);
        await tester.pump();

        expect(find.text('Too many incorrect attempts.'), findsOneWidget);
      },
    );

    testWidgets(
      'countdown text appears in PIN dialog after lockout is triggered',
      (tester) async {
        final container = await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Master PIN'));
        await tester.pumpAndSettle();

        await triggerLockout(tester, container);
        await tester.pump();

        expect(find.textContaining('Try again in'), findsOneWidget);
      },
    );

    testWidgets('lock_clock icon is shown in PIN dialog when locked', (
      tester,
    ) async {
      final container = await _pump(
        tester,
        fakeParental: fakeParental,
        fakeProfile: fakeProfile,
      );

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      await triggerLockout(tester, container);
      await tester.pump();

      expect(find.byIcon(Icons.lock_clock), findsOneWidget);
    });

    testWidgets('Submit button is absent from PIN dialog when locked', (
      tester,
    ) async {
      final container = await _pump(
        tester,
        fakeParental: fakeParental,
        fakeProfile: fakeProfile,
      );

      await tester.tap(find.text('Master PIN'));
      await tester.pumpAndSettle();

      await triggerLockout(tester, container);
      await tester.pump();

      // PinInputDialog hides FilledButton ("Submit") when locked.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets(
      'PIN fields are disabled (not rendered) when lockout is active',
      (tester) async {
        final container = await _pump(
          tester,
          fakeParental: fakeParental,
          fakeProfile: fakeProfile,
        );

        await tester.tap(find.text('Master PIN'));
        await tester.pumpAndSettle();

        await triggerLockout(tester, container);
        await tester.pump();

        // When locked, PinInputDialog hides the digit TextField widgets.
        expect(find.byType(TextField), findsNothing);
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
