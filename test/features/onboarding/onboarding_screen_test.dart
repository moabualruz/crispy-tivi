import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/iptv/application/playlist_sync_service.dart';
import 'package:crispy_tivi/features/onboarding/presentation/providers/onboarding_notifier.dart';
import 'package:crispy_tivi/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:crispy_tivi/features/onboarding/presentation/widgets/onboarding_step_indicator.dart';
import 'package:crispy_tivi/features/onboarding/presentation/widgets/onboarding_sync_step.dart';
import 'package:crispy_tivi/features/onboarding/presentation/widgets/onboarding_type_picker_step.dart';
import 'package:crispy_tivi/features/onboarding/presentation/widgets/onboarding_form_step.dart';
import 'package:crispy_tivi/features/onboarding/presentation/widgets/onboarding_welcome_step.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/source_form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Minimal AppConfig ─────────────────────────────────────────────────────

AppConfig _minimalConfig() => const AppConfig(
  appName: 'Test',
  appVersion: '0.0.0',
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

// ── Fakes ─────────────────────────────────────────────────────────────────

class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig(), sources: const []);

  @override
  Future<void> addSource(PlaylistSource source) async {}

  @override
  Future<void> removeSource(String id) async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class MockPlaylistSyncService extends Mock implements PlaylistSyncService {}

// ── Notifier that starts at a given initial state ─────────────────────────

class _PreloadedNotifier extends OnboardingNotifier {
  _PreloadedNotifier(this._initial);
  final OnboardingState _initial;

  @override
  OnboardingState build() => _initial;
}

// ── Notifier that records calls ───────────────────────────────────────────

class _RecordingNotifier extends OnboardingNotifier {
  _RecordingNotifier(this._initial);
  final OnboardingState _initial;
  final List<String> calls = [];

  @override
  OnboardingState build() => _initial;

  @override
  void goToStep(OnboardingStep step) {
    calls.add('goToStep:$step');
    super.goToStep(step);
  }

  @override
  void selectSourceType(PlaylistSourceType type) {
    calls.add('selectSourceType:$type');
    // Don't call super — avoid state mutation after widget tree tears down
  }

  @override
  void goBack() {
    calls.add('goBack');
    // Don't call super — avoid state mutation after widget tree tears down
  }

  @override
  Future<void> retrySync() async {
    calls.add('retrySync');
  }

  @override
  void editSource() {
    calls.add('editSource');
  }
}

// ── Widget builder helpers ────────────────────────────────────────────────

/// Builds the full [OnboardingScreen] with a notifier starting at [initial].
Widget _buildScreen({required OnboardingState initial}) {
  final backend = MemoryBackend();
  return ProviderScope(
    overrides: [
      cacheServiceProvider.overrideWithValue(CacheService(backend)),
      settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
      playlistSyncServiceProvider.overrideWith(
        (ref) => MockPlaylistSyncService(),
      ),
      onboardingProvider.overrideWith(() => _PreloadedNotifier(initial)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OnboardingScreen(),
    ),
  );
}

/// Builds a standalone step widget in isolation with the given [state].
Widget _buildStep({required Widget step, required OnboardingState state}) {
  final backend = MemoryBackend();
  return ProviderScope(
    overrides: [
      cacheServiceProvider.overrideWithValue(CacheService(backend)),
      settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
      playlistSyncServiceProvider.overrideWith(
        (ref) => MockPlaylistSyncService(),
      ),
      onboardingProvider.overrideWith(() => _PreloadedNotifier(state)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: step),
    ),
  );
}

/// Builds a standalone step widget in isolation with a recording notifier.
Widget _buildStepWithRecorder({
  required Widget step,
  required OnboardingState state,
  required _RecordingNotifier recorder,
}) {
  final backend = MemoryBackend();
  return ProviderScope(
    overrides: [
      cacheServiceProvider.overrideWithValue(CacheService(backend)),
      settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
      playlistSyncServiceProvider.overrideWith(
        (ref) => MockPlaylistSyncService(),
      ),
      onboardingProvider.overrideWith(() => recorder),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: step),
    ),
  );
}

void main() {
  setUp(() {
    registerFallbackValue(
      const PlaylistSource(
        id: 'fb',
        name: 'fb',
        url: 'http://fb',
        type: PlaylistSourceType.m3u,
      ),
    );
  });

  // ── OnboardingScreen ─────────────────────────────────────────────────

  group('OnboardingScreen', () {
    testWidgets('renders PopScope with canPop=false', (tester) async {
      await tester.pumpWidget(_buildScreen(initial: const OnboardingState()));
      await tester.pump();

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('renders step indicator with 3 dots', (tester) async {
      await tester.pumpWidget(_buildScreen(initial: const OnboardingState()));
      await tester.pump();

      final indicator = tester.widget<OnboardingStepIndicator>(
        find.byType(OnboardingStepIndicator),
      );
      expect(indicator.totalSteps, 3);
    });

    testWidgets('initial page shows OnboardingWelcomeStep', (tester) async {
      await tester.pumpWidget(_buildScreen(initial: const OnboardingState()));
      await tester.pump();

      expect(find.byType(OnboardingWelcomeStep), findsOneWidget);
    });
  });

  // ── WelcomeStep (tested in isolation) ────────────────────────────────

  group('OnboardingWelcomeStep', () {
    testWidgets('shows welcome heading', (tester) async {
      await tester.pumpWidget(
        _buildStep(
          step: const OnboardingWelcomeStep(),
          state: const OnboardingState(),
        ),
      );
      await tester.pump();

      expect(find.text('Welcome to CrispyTivi'), findsOneWidget);
    });

    testWidgets('shows Get Started button', (tester) async {
      await tester.pumpWidget(
        _buildStep(
          step: const OnboardingWelcomeStep(),
          state: const OnboardingState(),
        ),
      );
      await tester.pump();

      expect(find.text('Start Watching'), findsOneWidget);
    });

    testWidgets('tapping Get Started calls goToStep(typePicker)', (
      tester,
    ) async {
      final recorder = _RecordingNotifier(const OnboardingState());
      await tester.pumpWidget(
        _buildStepWithRecorder(
          step: const OnboardingWelcomeStep(),
          state: const OnboardingState(),
          recorder: recorder,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Start Watching'));
      await tester.pump();

      expect(recorder.calls, contains('goToStep:OnboardingStep.typePicker'));
    });
  });

  // ── TypePickerStep (tested in isolation) ─────────────────────────────

  group('OnboardingTypePickerStep', () {
    const typePicker = OnboardingState(step: OnboardingStep.typePicker);

    testWidgets('shows three source type cards', (tester) async {
      await tester.pumpWidget(
        _buildStep(step: const OnboardingTypePickerStep(), state: typePicker),
      );
      await tester.pump();

      expect(find.text('M3U Playlist'), findsOneWidget);
      expect(find.text('Xtream Codes'), findsOneWidget);
      expect(find.text('Stalker Portal'), findsOneWidget);
    });

    testWidgets('shows Back button', (tester) async {
      await tester.pumpWidget(
        _buildStep(step: const OnboardingTypePickerStep(), state: typePicker),
      );
      await tester.pump();

      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('tapping M3U card calls selectSourceType(m3u)', (tester) async {
      final recorder = _RecordingNotifier(typePicker);
      await tester.pumpWidget(
        _buildStepWithRecorder(
          step: const OnboardingTypePickerStep(),
          state: typePicker,
          recorder: recorder,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('M3U Playlist'));
      await tester.pump();

      expect(
        recorder.calls,
        contains('selectSourceType:PlaylistSourceType.m3u'),
      );
    });
  });

  // ── FormStep (tested in isolation) ───────────────────────────────────

  group('OnboardingFormStep — M3U', () {
    const m3uState = OnboardingState(
      step: OnboardingStep.form,
      sourceType: PlaylistSourceType.m3u,
    );

    testWidgets('shows M3uFormFields', (tester) async {
      await tester.pumpWidget(
        _buildStep(step: const OnboardingFormStep(), state: m3uState),
      );
      await tester.pump();

      expect(find.byType(M3uFormFields), findsOneWidget);
    });

    testWidgets('shows Name and Playlist URL fields', (tester) async {
      await tester.pumpWidget(
        _buildStep(step: const OnboardingFormStep(), state: m3uState),
      );
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Name'), findsWidgets);
      expect(find.widgetWithText(TextField, 'Playlist URL'), findsOneWidget);
    });

    testWidgets('tapping Connect with empty URL shows validation error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStep(step: const OnboardingFormStep(), state: m3uState),
      );
      await tester.pump();

      await tester.tap(find.text('Connect'));
      await tester.pump();

      expect(find.text('URL is required.'), findsOneWidget);
    });
  });

  group('OnboardingFormStep — Xtream', () {
    const xtreamState = OnboardingState(
      step: OnboardingStep.form,
      sourceType: PlaylistSourceType.xtream,
    );

    testWidgets('shows XtreamFormFields', (tester) async {
      await tester.pumpWidget(
        _buildStep(step: const OnboardingFormStep(), state: xtreamState),
      );
      await tester.pump();

      expect(find.byType(XtreamFormFields), findsOneWidget);
    });

    testWidgets('shows 4 text fields (Name, Server URL, Username, Password)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStep(step: const OnboardingFormStep(), state: xtreamState),
      );
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(4));
    });
  });

  group('OnboardingFormStep — Stalker', () {
    const stalkerState = OnboardingState(
      step: OnboardingStep.form,
      sourceType: PlaylistSourceType.stalkerPortal,
    );

    testWidgets('shows StalkerFormFields', (tester) async {
      await tester.pumpWidget(
        _buildStep(step: const OnboardingFormStep(), state: stalkerState),
      );
      await tester.pump();

      expect(find.byType(StalkerFormFields), findsOneWidget);
    });

    testWidgets('shows 3 text fields (Name, Portal URL, MAC)', (tester) async {
      await tester.pumpWidget(
        _buildStep(step: const OnboardingFormStep(), state: stalkerState),
      );
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('Stalker with invalid MAC shows validation error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStep(step: const OnboardingFormStep(), state: stalkerState),
      );
      await tester.pump();

      // Enter a valid URL
      final urlField = find.widgetWithText(TextField, 'Portal URL');
      await tester.enterText(urlField, 'http://portal.example.com');

      // Enter invalid MAC
      final macField = find.widgetWithText(TextField, 'MAC Address');
      await tester.enterText(macField, 'invalid-mac');

      await tester.tap(find.text('Connect'));
      await tester.pump();

      expect(find.textContaining('Invalid MAC address format'), findsOneWidget);
    });
  });

  // ── SyncStep (tested in isolation) ────────────────────────────────────

  group('OnboardingSyncStep', () {
    testWidgets('syncing: shows CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        _buildStep(
          step: const OnboardingSyncStep(),
          state: const OnboardingState(
            step: OnboardingStep.syncing,
            syncStatus: SyncStatus.syncing,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Connecting and loading channels\u2026'),
        findsOneWidget,
      );
    });

    testWidgets('success: shows check icon, channel count, Enter App', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStep(
          step: const OnboardingSyncStep(),
          state: const OnboardingState(
            step: OnboardingStep.syncing,
            syncStatus: SyncStatus.success,
            channelCount: 150,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('150 channels loaded!'), findsOneWidget);
      expect(find.text('Enter App'), findsOneWidget);
    });

    testWidgets('error: shows error icon, message, Retry, Edit', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStep(
          step: const OnboardingSyncStep(),
          state: const OnboardingState(
            step: OnboardingStep.syncing,
            syncStatus: SyncStatus.error,
            syncErrorMessage: 'Connection refused',
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Connection refused'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Edit source details'), findsOneWidget);
    });

    testWidgets('tapping Retry calls notifier.retrySync', (tester) async {
      const errorState = OnboardingState(
        step: OnboardingStep.syncing,
        syncStatus: SyncStatus.error,
        syncErrorMessage: 'timeout',
      );
      final recorder = _RecordingNotifier(errorState);

      await tester.pumpWidget(
        _buildStepWithRecorder(
          step: const OnboardingSyncStep(),
          state: errorState,
          recorder: recorder,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(recorder.calls, contains('retrySync'));
    });

    testWidgets('tapping Edit calls notifier.editSource', (tester) async {
      const errorState = OnboardingState(
        step: OnboardingStep.syncing,
        syncStatus: SyncStatus.error,
        syncErrorMessage: 'timeout',
      );
      final recorder = _RecordingNotifier(errorState);

      await tester.pumpWidget(
        _buildStepWithRecorder(
          step: const OnboardingSyncStep(),
          state: errorState,
          recorder: recorder,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Edit source details'));
      await tester.pump();

      expect(recorder.calls, contains('editSource'));
    });
  });
}
