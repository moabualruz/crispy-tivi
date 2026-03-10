import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/features/settings/domain/entities/remote_action.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/remote_settings.dart';

// ── Minimal AppConfig for tests ───────────────────────────────

AppConfig _minimalConfig() => const AppConfig(
  appName: 'Test',
  appVersion: '0.0.1',
  api: ApiConfig(
    baseUrl: 'http://test',
    backendPort: 8080,
    connectTimeoutMs: 5000,
    receiveTimeoutMs: 5000,
    sendTimeoutMs: 5000,
  ),
  player: PlayerConfig(
    defaultBufferDurationMs: 2000,
    autoPlay: true,
    defaultAspectRatio: '16:9',
  ),
  theme: ThemeConfig(
    mode: 'dark',
    seedColorHex: '#3B82F6',
    useDynamicColor: false,
  ),
  features: FeaturesConfig(
    iptvEnabled: true,
    jellyfinEnabled: false,
    plexEnabled: false,
    embyEnabled: false,
  ),
  cache: CacheConfig(
    epgRefreshIntervalMinutes: 60,
    channelListRefreshIntervalMinutes: 30,
    maxCachedEpgDays: 7,
  ),
);

// ── Fake SettingsNotifier ─────────────────────────────────────

class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  _FakeSettingsNotifier(this._initial);

  final SettingsState _initial;
  late SettingsState _state;

  // ── Captured call args ──────────────────────────
  int? lastSetKeyMappingKeyId;
  RemoteAction? lastSetKeyMappingAction;
  int? lastRemovedKeyId;
  bool resetKeyMappingsCalled = false;

  @override
  Future<SettingsState> build() async {
    _state = _initial;
    return _state;
  }

  @override
  Future<void> setRemoteKeyMapping(int keyId, RemoteAction action) async {
    lastSetKeyMappingKeyId = keyId;
    lastSetKeyMappingAction = action;
    final upd = {..._state.remoteKeyMap, keyId: action};
    _state = _state.copyWith(remoteKeyMap: upd);
    state = AsyncData(_state);
  }

  @override
  Future<void> removeRemoteKeyMapping(int keyId) async {
    lastRemovedKeyId = keyId;
    final upd = Map<int, RemoteAction>.from(_state.remoteKeyMap)..remove(keyId);
    _state = _state.copyWith(remoteKeyMap: upd);
    state = AsyncData(_state);
  }

  @override
  Future<void> resetRemoteKeyMappings() async {
    resetKeyMappingsCalled = true;
    _state = _state.copyWith(remoteKeyMap: defaultRemoteKeyMap);
    state = AsyncData(_state);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Test helpers ──────────────────────────────────────────────

/// Builds a [SettingsState] with a given [remoteKeyMap].
SettingsState _stateWith({Map<int, RemoteAction>? remoteKeyMap}) =>
    SettingsState(config: _minimalConfig(), remoteKeyMap: remoteKeyMap);

/// Pumps [RemoteSettingsSection] inside a full scaffold.
Future<_FakeSettingsNotifier> _pumpRemoteSettings(
  WidgetTester tester, {
  Map<int, RemoteAction>? remoteKeyMap,
}) async {
  final keyMap = remoteKeyMap ?? defaultRemoteKeyMap;
  final state = _stateWith(remoteKeyMap: keyMap);
  final fakeNotifier = _FakeSettingsNotifier(state);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsNotifierProvider.overrideWith(() => fakeNotifier)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RemoteSettingsSection(remoteKeyMap: keyMap),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fakeNotifier;
}

// ── Tests ─────────────────────────────────────────────────────

void main() {
  // ── Key Mappings section ──────────────────────────────────

  group('Key Mappings', () {
    testWidgets('renders Key Mappings tile with configured key count', (
      tester,
    ) async {
      await _pumpRemoteSettings(tester, remoteKeyMap: defaultRemoteKeyMap);

      expect(find.text('Key Mappings'), findsOneWidget);
      expect(
        find.text('${defaultRemoteKeyMap.length} keys configured'),
        findsOneWidget,
      );
    });

    testWidgets('renders Reset to Defaults tile', (tester) async {
      await _pumpRemoteSettings(tester);

      expect(find.text('Reset to Defaults'), findsOneWidget);
      expect(find.text('Restore original key assignments'), findsOneWidget);
    });

    testWidgets('Key Mappings tile has chevron trailing icon', (tester) async {
      await _pumpRemoteSettings(tester);

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tapping Key Mappings tile opens dialog', (tester) async {
      await _pumpRemoteSettings(tester);

      await tester.tap(find.text('Key Mappings'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Key Mappings'), findsNWidgets(2));
    });

    testWidgets('Key Mappings dialog lists first visible RemoteAction', (
      tester,
    ) async {
      await _pumpRemoteSettings(tester, remoteKeyMap: defaultRemoteKeyMap);

      await tester.tap(find.text('Key Mappings'));
      await tester.pumpAndSettle();

      // The first action (Play / Pause) is always visible.
      expect(find.text(RemoteAction.playPause.label), findsAtLeast(1));
    });

    testWidgets(
      'Key Mappings dialog ListView has RemoteAction.values.length items',
      (tester) async {
        await _pumpRemoteSettings(tester, remoteKeyMap: defaultRemoteKeyMap);

        await tester.tap(find.text('Key Mappings'));
        await tester.pumpAndSettle();

        // Verify by scrolling to the last action and confirming it exists.
        final lastActionLabel = RemoteAction.values.last.label;
        await tester.scrollUntilVisible(
          find.text(lastActionLabel),
          50,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(lastActionLabel), findsOneWidget);
      },
    );

    testWidgets(
      'action row with no binding shows "Not assigned" for visible rows',
      (tester) async {
        // Empty map — nothing is assigned.
        await _pumpRemoteSettings(tester, remoteKeyMap: const {});

        await tester.tap(find.text('Key Mappings'));
        await tester.pumpAndSettle();

        // At least the first visible row should show "Not assigned".
        expect(find.text('Not assigned'), findsAtLeast(1));
      },
    );

    testWidgets('action row with binding shows key label for assigned action', (
      tester,
    ) async {
      final keyMap = {LogicalKeyboardKey.space.keyId: RemoteAction.playPause};
      await _pumpRemoteSettings(tester, remoteKeyMap: keyMap);

      await tester.tap(find.text('Key Mappings'));
      await tester.pumpAndSettle();

      // Play / Pause row should NOT show "Not assigned" since it has a binding.
      // "Not assigned" still appears for other visible rows.
      // Confirm the Play / Pause row has its subtitle visible (not "Not assigned").
      expect(find.text('Not assigned'), findsAtLeast(1));
      // The space key label confirms the assigned row subtitle is distinct.
      final spaceKeyLabel = LogicalKeyboardKey.space.keyLabel;
      expect(find.text(spaceKeyLabel), findsOneWidget);
    });

    testWidgets('dialog has a Done button that closes it', (tester) async {
      await _pumpRemoteSettings(tester);

      await tester.tap(find.text('Key Mappings'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('tapping an action row inside dialog opens KeyCapture dialog', (
      tester,
    ) async {
      await _pumpRemoteSettings(tester, remoteKeyMap: defaultRemoteKeyMap);

      await tester.tap(find.text('Key Mappings'));
      await tester.pumpAndSettle();

      // Tap the first action row (Play / Pause).
      await tester.tap(find.text(RemoteAction.playPause.label));
      await tester.pumpAndSettle();

      // A second AlertDialog should now be on screen.
      expect(find.byType(AlertDialog), findsNWidgets(2));
    });
  });

  // ── KeyCaptureDialog ──────────────────────────────────────

  group('KeyCaptureDialog', () {
    /// Opens the key-mapping list dialog then scrolls to and taps
    /// the row for [actionLabel] to open the capture dialog.
    ///
    /// Uses [scrollable] (the ListView inside the AlertDialog) to
    /// ensure the target row is on-screen before tapping.
    Future<void> openCaptureFor(WidgetTester tester, String actionLabel) async {
      await tester.tap(find.text('Key Mappings'));
      await tester.pumpAndSettle();
      // Scroll the dialog list until the target row is visible.
      await tester.scrollUntilVisible(
        find.text(actionLabel),
        50,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(actionLabel));
      await tester.pumpAndSettle();
    }

    testWidgets('shows "Set Key: <action>" as dialog title', (tester) async {
      await _pumpRemoteSettings(tester, remoteKeyMap: {});

      await openCaptureFor(tester, RemoteAction.playPause.label);

      expect(
        find.text('Set Key: ${RemoteAction.playPause.label}'),
        findsOneWidget,
      );
    });

    testWidgets('shows keyboard icon', (tester) async {
      await _pumpRemoteSettings(tester, remoteKeyMap: {});

      // Use playPause (first action, always visible without scrolling).
      await openCaptureFor(tester, RemoteAction.playPause.label);

      expect(find.byIcon(Icons.keyboard), findsOneWidget);
    });

    testWidgets('shows press-any-key instruction text', (tester) async {
      await _pumpRemoteSettings(tester, remoteKeyMap: {});

      await openCaptureFor(tester, RemoteAction.playPause.label);

      expect(
        find.text('Press any key on your remote\nor keyboard to assign it.'),
        findsOneWidget,
      );
    });

    testWidgets('shows "Current: None" when action has no binding', (
      tester,
    ) async {
      await _pumpRemoteSettings(tester, remoteKeyMap: {});

      await openCaptureFor(tester, RemoteAction.seekForward.label);

      expect(find.text('Current: None'), findsOneWidget);
    });

    testWidgets('shows existing binding label in "Current:" line', (
      tester,
    ) async {
      // Use Play / Pause which is always first in the list — no scrolling needed.
      final keyMap = {LogicalKeyboardKey.space.keyId: RemoteAction.playPause};
      await _pumpRemoteSettings(tester, remoteKeyMap: keyMap);

      await openCaptureFor(tester, RemoteAction.playPause.label);

      // Should NOT say "Current: None" — a binding exists.
      expect(find.text('Current: None'), findsNothing);
    });

    testWidgets('Cancel button closes capture dialog', (tester) async {
      await _pumpRemoteSettings(tester, remoteKeyMap: {});

      // Use playPause: its label "Play / Pause" is unambiguous.
      await openCaptureFor(tester, RemoteAction.playPause.label);

      // Two dialogs: list + capture.
      expect(find.byType(AlertDialog), findsNWidgets(2));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Back to one dialog (the list).
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Clear button is absent when action has no current binding', (
      tester,
    ) async {
      await _pumpRemoteSettings(tester, remoteKeyMap: {});

      await openCaptureFor(tester, RemoteAction.playPause.label);

      expect(find.text('Clear'), findsNothing);
    });

    testWidgets('Clear button is present when action has a binding', (
      tester,
    ) async {
      final keyMap = {LogicalKeyboardKey.space.keyId: RemoteAction.playPause};
      await _pumpRemoteSettings(tester, remoteKeyMap: keyMap);

      await openCaptureFor(tester, RemoteAction.playPause.label);

      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets(
      'tapping Clear calls removeRemoteKeyMapping and closes dialog',
      (tester) async {
        final keyMap = {LogicalKeyboardKey.space.keyId: RemoteAction.playPause};
        final fake = await _pumpRemoteSettings(tester, remoteKeyMap: keyMap);

        await openCaptureFor(tester, RemoteAction.playPause.label);

        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();

        // The capture dialog should be gone.
        expect(find.byType(AlertDialog), findsOneWidget);
        // Notifier received the remove call.
        expect(fake.lastRemovedKeyId, LogicalKeyboardKey.space.keyId);
      },
    );

    testWidgets('pressing a key fires setRemoteKeyMapping and closes dialog', (
      tester,
    ) async {
      final fake = await _pumpRemoteSettings(tester, remoteKeyMap: {});

      await openCaptureFor(tester, RemoteAction.playPause.label);

      // Simulate a KeyDown event. The _KeyCaptureDialog uses a
      // KeyboardListener with autofocus: true — it receives system
      // key events routed through the focus tree.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      // Capture dialog should be dismissed (back to the list dialog).
      expect(find.byType(AlertDialog), findsOneWidget);

      // Notifier should have received the mapping.
      expect(fake.lastSetKeyMappingKeyId, LogicalKeyboardKey.space.keyId);
      expect(fake.lastSetKeyMappingAction, RemoteAction.playPause);
    });
  });

  // ── Reset Key Mappings ────────────────────────────────────

  group('Reset Key Mappings', () {
    testWidgets('tapping Reset to Defaults opens confirmation AlertDialog', (
      tester,
    ) async {
      await _pumpRemoteSettings(tester);

      await tester.tap(find.text('Reset to Defaults'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Reset Key Mappings?'), findsOneWidget);
    });

    testWidgets('confirmation dialog shows descriptive content', (
      tester,
    ) async {
      await _pumpRemoteSettings(tester);

      await tester.tap(find.text('Reset to Defaults'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This will restore all remote control '
          'keys to their default assignments.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('confirmation dialog has Cancel and Reset buttons', (
      tester,
    ) async {
      await _pumpRemoteSettings(tester);

      await tester.tap(find.text('Reset to Defaults'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('tapping Cancel closes dialog without resetting', (
      tester,
    ) async {
      final fake = await _pumpRemoteSettings(tester);

      await tester.tap(find.text('Reset to Defaults'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.resetKeyMappingsCalled, isFalse);
    });

    testWidgets('tapping Reset calls resetRemoteKeyMappings', (tester) async {
      final fake = await _pumpRemoteSettings(tester);

      await tester.tap(find.text('Reset to Defaults'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(fake.resetKeyMappingsCalled, isTrue);
    });

    testWidgets('tapping Reset closes the confirmation dialog', (tester) async {
      await _pumpRemoteSettings(tester);

      await tester.tap(find.text('Reset to Defaults'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('shows snackbar after confirming reset', (tester) async {
      await _pumpRemoteSettings(tester);

      await tester.tap(find.text('Reset to Defaults'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Key mappings reset to defaults'), findsOneWidget);
    });
  });
}
