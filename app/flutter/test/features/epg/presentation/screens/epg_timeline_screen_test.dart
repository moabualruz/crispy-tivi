import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/dvr/data/dvr_service.dart';
import 'package:crispy_tivi/features/epg/presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/epg/presentation/screens/epg_timeline_screen.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/playlist_sync_service.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';
import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';

class _MockPlayerService extends Mock implements PlayerService {}

/// Stub PlaylistSyncService that does nothing.
class _NoOpSyncService extends PlaylistSyncService {
  _NoOpSyncService(super.ref);

  @override
  Future<int> syncAll({bool force = false}) async => 0;

  @override
  Future<void> refreshEpg() async {}
}

/// Fake EpgNotifier pre-loaded with test data so
/// [fetchEpgWindow] (which calls the cache/backend) is
/// never triggered.
class _FakeEpgNotifier extends EpgNotifier {
  _FakeEpgNotifier(this._channels, this._entries);

  final List<Channel> _channels;
  final Map<String, List<EpgEntry>> _entries;

  @override
  EpgState build() {
    return EpgState(
      channels: _channels,
      entries: _entries,
      focusedTime: DateTime.now(),
      viewMode: EpgViewMode.day,
      isLoading: false,
      showEpgOnly: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('EpgTimelineScreen renders channels and programs', (
    tester,
  ) async {
    final now = DateTime.now();
    final channel = Channel(
      id: 'ch1',
      name: 'Channel 1',
      streamUrl: 'http://test',
    );
    final entry = EpgEntry(
      channelId: 'ch1',
      title: 'Program A',
      startTime: now.subtract(const Duration(minutes: 30)),
      endTime: now.add(const Duration(hours: 1)),
    );

    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

    final mockPlayer = _MockPlayerService();
    when(() => mockPlayer.currentUrl).thenReturn(null);
    when(
      () => mockPlayer.play(
        any(),
        isLive: any(named: 'isLive'),
        channelName: any(named: 'channelName'),
        channelLogoUrl: any(named: 'channelLogoUrl'),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          crispyBackendProvider.overrideWithValue(testBackend),
          cacheServiceProvider.overrideWithValue(testCache),
          playerServiceProvider.overrideWithValue(mockPlayer),
          playbackStateProvider.overrideWith(
            (ref) => Stream<PlaybackState>.empty(),
          ),
          playlistSyncServiceProvider.overrideWith(
            (ref) => _NoOpSyncService(ref),
          ),
          dvrServiceProvider.overrideWith(() => _StubDvrService()),
          epgProvider.overrideWith(
            () => _FakeEpgNotifier(
              [channel],
              {
                'ch1': [entry],
              },
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EpgTimelineScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Channel 1'), findsWidgets);
    expect(find.text('Program A'), findsWidgets);
  });
}

/// Stub DvrService that returns an empty [DvrState]
/// without touching the real cache/backend.
class _StubDvrService extends DvrService {
  @override
  Future<DvrState> build() async => const DvrState();
}
