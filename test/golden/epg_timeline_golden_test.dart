import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/epg/presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/epg/presentation/screens/epg_timeline_screen.dart';
import 'package:crispy_tivi/features/iptv/application/playlist_sync_service.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';
import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';

class _MockPlayerService extends Mock implements PlayerService {}

const _testConfigJson = '''
{
  "appName": "CrispyTivi",
  "appVersion": "0.1.0-test",
  "api": {
    "baseUrl": "http://localhost",
    "backendPort": 8080,
    "connectTimeoutMs": 10000,
    "receiveTimeoutMs": 30000,
    "sendTimeoutMs": 10000
  },
  "player": {
    "defaultBufferDurationMs": 5000,
    "hwdecMode": "auto",
    "autoPlay": false,
    "defaultAspectRatio": "16:9",
    "afrEnabled": false,
    "afrLiveTv": true,
    "afrVod": true,
    "pipOnMinimize": true,
    "streamProfile": "auto",
    "recordingProfile": "original",
    "epgTimezone": "system",
    "audioOutput": "auto",
    "audioPassthroughEnabled": false,
    "audioPassthroughCodecs": ["ac3", "dts"]
  },
  "theme": {
    "mode": "dark",
    "seedColorHex": "#6750A4",
    "useDynamicColor": false
  },
  "features": {
    "iptvEnabled": true,
    "jellyfinEnabled": false,
    "plexEnabled": false,
    "embyEnabled": false
  },
  "cache": {
    "epgRefreshIntervalMinutes": 360,
    "channelListRefreshIntervalMinutes": 60,
    "maxCachedEpgDays": 7
  }
}
''';

/// Fixed time anchor for deterministic golden
/// output.
final _anchor = DateTime.utc(2025, 6, 15, 12, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.useGoogleFonts = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('EpgTimelineScreen golden — day view with '
      'entries', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          epgClockProvider.overrideWithValue(() => _anchor),
          crispyBackendProvider.overrideWithValue(testBackend),
          cacheServiceProvider.overrideWithValue(testCache),
          playerServiceProvider.overrideWithValue(mockPlayer),
          configServiceProvider.overrideWith((ref) async {
            final c = ref.read(cacheServiceProvider);
            final b = ref.read(crispyBackendProvider);
            final service = ConfigService(
              assetLoader: (_) async => _testConfigJson,
              cacheService: c,
              backend: b,
            );
            return service.load();
          }),
          playlistSyncServiceProvider.overrideWith(
            (ref) => _NoOpSyncService(ref),
          ),
          playbackStateProvider.overrideWith(
            (ref) => Stream<PlaybackState>.empty(),
          ),
          epgProvider.overrideWith(_FakeEpgNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const EpgTimelineScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(EpgTimelineScreen),
      matchesGoldenFile('goldens/epg_timeline_day.png'),
    );
  });
}

class _NoOpSyncService extends PlaylistSyncService {
  _NoOpSyncService(super.ref);

  @override
  Future<int> syncAll({bool force = false}) async => 0;
}

class _FakeEpgNotifier extends EpgNotifier {
  @override
  EpgState build() {
    return EpgState(
      channels: const [
        Channel(
          id: 'ch1',
          name: 'BBC One',
          streamUrl: 'http://test/1',
          group: 'News',
        ),
        Channel(
          id: 'ch2',
          name: 'CNN',
          streamUrl: 'http://test/2',
          group: 'News',
        ),
        Channel(
          id: 'ch3',
          name: 'ESPN',
          streamUrl: 'http://test/3',
          group: 'Sports',
        ),
      ],
      entries: {
        'ch1': [
          EpgEntry(
            channelId: 'ch1',
            title: 'Morning News',
            startTime: _anchor.subtract(const Duration(hours: 2)),
            endTime: _anchor,
          ),
          EpgEntry(
            channelId: 'ch1',
            title: 'World Report',
            startTime: _anchor,
            endTime: _anchor.add(const Duration(hours: 1)),
          ),
          EpgEntry(
            channelId: 'ch1',
            title: 'Documentary',
            startTime: _anchor.add(const Duration(hours: 1)),
            endTime: _anchor.add(const Duration(hours: 3)),
          ),
        ],
        'ch2': [
          EpgEntry(
            channelId: 'ch2',
            title: 'CNN Tonight',
            startTime: _anchor.subtract(const Duration(hours: 1)),
            endTime: _anchor.add(const Duration(hours: 1)),
          ),
          EpgEntry(
            channelId: 'ch2',
            title: 'Anderson Cooper 360',
            startTime: _anchor.add(const Duration(hours: 1)),
            endTime: _anchor.add(const Duration(hours: 2)),
          ),
        ],
        'ch3': [
          EpgEntry(
            channelId: 'ch3',
            title: 'SportsCenter',
            startTime: _anchor.subtract(const Duration(hours: 3)),
            endTime: _anchor,
          ),
          EpgEntry(
            channelId: 'ch3',
            title: 'NBA Basketball',
            startTime: _anchor,
            endTime: _anchor.add(const Duration(hours: 3)),
          ),
        ],
      },
      focusedTime: _anchor,
      viewMode: EpgViewMode.day,
    );
  }
}
