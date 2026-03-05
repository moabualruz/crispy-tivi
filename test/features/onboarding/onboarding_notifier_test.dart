import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/iptv/application/playlist_sync_service.dart';
import 'package:crispy_tivi/features/onboarding/presentation/providers/onboarding_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Minimal AppConfig for tests ───────────────────────────────────────────

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

// ── Fake SettingsNotifier ─────────────────────────────────────────────────

/// Records addSource / removeSource calls without hitting any backend.
class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  final List<String> addedSourceIds = [];
  final List<String> removedSourceIds = [];

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig(), sources: const []);

  @override
  Future<void> addSource(PlaylistSource source) async {
    addedSourceIds.add(source.id);
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(sources: [...current.sources, source]),
      );
    }
  }

  @override
  Future<void> removeSource(String id) async {
    removedSourceIds.add(id);
    final current = state.value;
    if (current != null) {
      final upd = current.sources.where((s) => s.id != id).toList();
      state = AsyncData(current.copyWith(sources: upd));
    }
  }

  // Stubs for remaining SettingsNotifier methods (not exercised by these tests).
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Mock PlaylistSyncService ──────────────────────────────────────────────

class MockPlaylistSyncService extends Mock implements PlaylistSyncService {}

// ── Helpers ────────────────────────────────────────────────────────────────

PlaylistSource _makeSource({
  String id = 'src_1',
  String url = 'http://test.m3u',
}) {
  return PlaylistSource(
    id: id,
    name: 'Test Source',
    url: url,
    type: PlaylistSourceType.m3u,
  );
}

/// Creates a [SyncReport] with [count] channels.
SyncReport _syncReport(int count) {
  return SyncReport(channelsCount: count);
}

// ── Container factory ──────────────────────────────────────────────────────

ProviderContainer _makeContainer({
  required _FakeSettingsNotifier settingsFake,
  required MockPlaylistSyncService syncMock,
}) {
  final backend = MemoryBackend();
  return ProviderContainer(
    overrides: [
      crispyBackendProvider.overrideWithValue(backend),
      cacheServiceProvider.overrideWithValue(CacheService(backend)),
      settingsNotifierProvider.overrideWith(() => settingsFake),
      playlistSyncServiceProvider.overrideWith((ref) => syncMock),
    ],
  );
}

void main() {
  late _FakeSettingsNotifier fakeSettings;
  late MockPlaylistSyncService mockSync;
  late ProviderContainer container;

  setUp(() {
    registerFallbackValue(
      const PlaylistSource(
        id: 'fallback',
        name: 'fallback',
        url: 'http://fallback',
        type: PlaylistSourceType.m3u,
      ),
    );

    fakeSettings = _FakeSettingsNotifier();
    mockSync = MockPlaylistSyncService();

    container = _makeContainer(settingsFake: fakeSettings, syncMock: mockSync);
  });

  tearDown(() => container.dispose());

  OnboardingNotifier notifier() => container.read(onboardingProvider.notifier);
  OnboardingState state() => container.read(onboardingProvider);

  // ── Initial state ──────────────────────────────────────────────────────

  test('initial state is welcome step with idle sync', () {
    final s = state();
    expect(s.step, OnboardingStep.welcome);
    expect(s.syncStatus, SyncStatus.idle);
    expect(s.sourceType, isNull);
    expect(s.channelCount, 0);
    expect(s.lastSource, isNull);
    expect(s.syncErrorMessage, isNull);
  });

  // ── goToStep ────────────────────────────────────────────────────────────

  group('goToStep', () {
    test('transitions from welcome to typePicker', () {
      notifier().goToStep(OnboardingStep.typePicker);
      expect(state().step, OnboardingStep.typePicker);
    });

    test('can go to form step directly', () {
      notifier().goToStep(OnboardingStep.form);
      expect(state().step, OnboardingStep.form);
    });
  });

  // ── selectSourceType ────────────────────────────────────────────────────

  group('selectSourceType', () {
    test('sets m3u sourceType and advances to form', () {
      notifier().selectSourceType(PlaylistSourceType.m3u);
      final s = state();
      expect(s.sourceType, PlaylistSourceType.m3u);
      expect(s.step, OnboardingStep.form);
    });

    test('sets xtream sourceType and advances to form', () {
      notifier().selectSourceType(PlaylistSourceType.xtream);
      final s = state();
      expect(s.sourceType, PlaylistSourceType.xtream);
      expect(s.step, OnboardingStep.form);
    });

    test('sets stalkerPortal sourceType and advances to form', () {
      notifier().selectSourceType(PlaylistSourceType.stalkerPortal);
      final s = state();
      expect(s.sourceType, PlaylistSourceType.stalkerPortal);
      expect(s.step, OnboardingStep.form);
    });
  });

  // ── goBack ──────────────────────────────────────────────────────────────

  group('goBack', () {
    test('from form → typePicker', () {
      notifier().goToStep(OnboardingStep.form);
      notifier().goBack();
      expect(state().step, OnboardingStep.typePicker);
    });

    test('from typePicker → welcome', () {
      notifier().goToStep(OnboardingStep.typePicker);
      notifier().goBack();
      expect(state().step, OnboardingStep.welcome);
    });

    test('from welcome → stays welcome (no-op)', () {
      notifier().goBack();
      expect(state().step, OnboardingStep.welcome);
    });

    test('from syncing → stays syncing (no-op)', () {
      notifier().goToStep(OnboardingStep.syncing);
      notifier().goBack();
      expect(state().step, OnboardingStep.syncing);
    });
  });

  // ── submitSource success ─────────────────────────────────────────────────

  group('submitSource success', () {
    test('transitions to syncing then success with channel count', () async {
      final source = _makeSource();
      when(
        () => mockSync.syncSource(any()),
      ).thenAnswer((_) async => _syncReport(3));

      await notifier().submitSource(source);

      final s = state();
      expect(s.syncStatus, SyncStatus.success);
      expect(s.channelCount, 3);
      expect(s.lastSource, source);
      expect(s.step, OnboardingStep.syncing);
      expect(s.syncErrorMessage, isNull);
    });

    test('calls addSource before sync', () async {
      final source = _makeSource();
      when(
        () => mockSync.syncSource(any()),
      ).thenAnswer((_) async => _syncReport(5));

      await notifier().submitSource(source);

      expect(fakeSettings.addedSourceIds, contains(source.id));
    });

    test('sets lastSource to the submitted source', () async {
      final source = _makeSource(id: 'src_42');
      when(
        () => mockSync.syncSource(any()),
      ).thenAnswer((_) async => _syncReport(10));

      await notifier().submitSource(source);

      expect(state().lastSource?.id, 'src_42');
    });

    test('channelCount reflects actual result', () async {
      final source = _makeSource();
      when(
        () => mockSync.syncSource(any()),
      ).thenAnswer((_) async => _syncReport(99));

      await notifier().submitSource(source);

      expect(state().channelCount, 99);
    });
  });

  // ── submitSource error ───────────────────────────────────────────────────

  group('submitSource error', () {
    test('transitions to error with message', () async {
      final source = _makeSource();
      when(
        () => mockSync.syncSource(any()),
      ).thenThrow(Exception('Network timeout'));

      await notifier().submitSource(source);

      final s = state();
      expect(s.syncStatus, SyncStatus.error);
      expect(s.syncErrorMessage, contains('Network timeout'));
      expect(s.step, OnboardingStep.syncing);
    });

    test('still calls addSource even when sync throws', () async {
      final source = _makeSource();
      when(
        () => mockSync.syncSource(any()),
      ).thenThrow(Exception('Network timeout'));

      await notifier().submitSource(source);

      expect(fakeSettings.addedSourceIds, contains(source.id));
    });

    test('stores lastSource on error', () async {
      final source = _makeSource(id: 'err_src');
      when(() => mockSync.syncSource(any())).thenThrow(Exception('Timeout'));

      await notifier().submitSource(source);

      expect(state().lastSource?.id, 'err_src');
    });

    test('syncErrorMessage is non-null on error', () async {
      final source = _makeSource();
      when(() => mockSync.syncSource(any())).thenThrow(Exception('boom'));

      await notifier().submitSource(source);

      expect(state().syncStatus, SyncStatus.error);
      expect(state().syncErrorMessage, isNotNull);
    });
  });

  // ── retrySync success ────────────────────────────────────────────────────

  group('retrySync success', () {
    Future<void> putInErrorState(PlaylistSource source) async {
      when(() => mockSync.syncSource(any())).thenThrow(Exception('first fail'));
      await notifier().submitSource(source);
    }

    test('transitions error → syncing → success', () async {
      final source = _makeSource();
      await putInErrorState(source);
      expect(state().syncStatus, SyncStatus.error);

      when(
        () => mockSync.syncSource(any()),
      ).thenAnswer((_) async => _syncReport(7));
      await notifier().retrySync();

      final s = state();
      expect(s.syncStatus, SyncStatus.success);
      expect(s.channelCount, 7);
      expect(s.syncErrorMessage, isNull);
    });

    test('does not call syncSource if lastSource is null', () async {
      await notifier().retrySync();
      verifyNever(() => mockSync.syncSource(any()));
    });
  });

  // ── retrySync error ──────────────────────────────────────────────────────

  group('retrySync error', () {
    test('transitions error → syncing → error again', () async {
      final source = _makeSource();
      when(() => mockSync.syncSource(any())).thenThrow(Exception('first fail'));
      await notifier().submitSource(source);
      expect(state().syncStatus, SyncStatus.error);

      when(
        () => mockSync.syncSource(any()),
      ).thenThrow(Exception('still failing'));
      await notifier().retrySync();

      final s = state();
      expect(s.syncStatus, SyncStatus.error);
      expect(s.syncErrorMessage, contains('still failing'));
    });
  });

  // ── editSource ───────────────────────────────────────────────────────────

  group('editSource', () {
    test('calls removeSource with lastSource.id and resets state', () async {
      final source = _makeSource(id: 'to_remove');
      when(() => mockSync.syncSource(any())).thenThrow(Exception('fail'));
      await notifier().submitSource(source);
      expect(state().syncStatus, SyncStatus.error);

      notifier().editSource();

      expect(fakeSettings.removedSourceIds, contains('to_remove'));
      final s = state();
      expect(s.step, OnboardingStep.form);
      expect(s.syncStatus, SyncStatus.idle);
      expect(s.syncErrorMessage, isNull);
    });

    test('does not call removeSource if lastSource is null', () {
      notifier().editSource();
      expect(fakeSettings.removedSourceIds, isEmpty);
    });

    test('resets to form step regardless of lastSource', () {
      notifier().editSource();
      expect(state().step, OnboardingStep.form);
      expect(state().syncStatus, SyncStatus.idle);
      expect(state().syncErrorMessage, isNull);
    });
  });
}
