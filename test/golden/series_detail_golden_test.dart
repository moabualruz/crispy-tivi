import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_favorites_provider.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/vod/presentation/screens/series_detail_screen.dart';
import 'package:crispy_tivi/features/vod/presentation/widgets/series_episode_fetcher.dart';

const _testConfigJson = '''
{
  "appName": "CrispyTivi",
  "appVersion": "0.1.0-test",
  "api": { "baseUrl": "http://localhost", "backendPort": 8080, "connectTimeoutMs": 10000, "receiveTimeoutMs": 30000, "sendTimeoutMs": 10000 },
  "player": { "defaultBufferDurationMs": 5000, "hwdecMode": "auto", "autoPlay": false, "defaultAspectRatio": "16:9", "afrEnabled": false, "afrLiveTv": true, "afrVod": true, "pipOnMinimize": true, "streamProfile": "auto", "recordingProfile": "original", "epgTimezone": "system", "audioOutput": "auto", "audioPassthroughEnabled": false, "audioPassthroughCodecs": ["ac3", "dts"] },
  "theme": { "mode": "dark", "seedColorHex": "#6750A4", "useDynamicColor": false },
  "features": { "iptvEnabled": true, "jellyfinEnabled": false, "plexEnabled": false, "embyEnabled": false },
  "cache": { "epgRefreshIntervalMinutes": 360, "channelListRefreshIntervalMinutes": 60, "maxCachedEpgDays": 7 }
}
''';

const _testSeries = VodItem(
  id: 'series-1',
  name: 'Breaking Bad',
  streamUrl: 'http://test/series/1',
  type: VodType.series,
  category: 'Drama',
  rating: '9.5',
  year: 2008,
  description:
      'A high school chemistry teacher diagnosed with inoperable lung '
      'cancer turns to manufacturing and selling methamphetamine.',
);

final _testEpisodeResult = EpisodeFetchResult(
  episodes: const [
    VodItem(
      id: 'ep-s1-e1',
      name: 'Pilot',
      streamUrl: 'http://test/ep/1',
      type: VodType.movie,
      category: 'Drama',
      seasonNumber: 1,
      episodeNumber: 1,
      duration: 58,
    ),
    VodItem(
      id: 'ep-s1-e2',
      name: "Cat's in the Bag",
      streamUrl: 'http://test/ep/2',
      type: VodType.movie,
      category: 'Drama',
      seasonNumber: 1,
      episodeNumber: 2,
      duration: 48,
    ),
    VodItem(
      id: 'ep-s1-e3',
      name: "...And the Bag's in the River",
      streamUrl: 'http://test/ep/3',
      type: VodType.movie,
      category: 'Drama',
      seasonNumber: 1,
      episodeNumber: 3,
      duration: 47,
    ),
    VodItem(
      id: 'ep-s2-e1',
      name: 'Seven Thirty-Seven',
      streamUrl: 'http://test/ep/4',
      type: VodType.movie,
      category: 'Drama',
      seasonNumber: 2,
      episodeNumber: 1,
      duration: 47,
    ),
  ],
  seasons: [1, 2],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.useGoogleFonts = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'SeriesDetailScreen golden — compact Episodes tab with season selector',
    (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);

      final router = GoRouter(
        initialLocation: '/series',
        routes: [
          GoRoute(
            path: '/series',
            builder: (_, _) => const SeriesDetailScreen(series: _testSeries),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            crispyBackendProvider.overrideWithValue(testBackend),
            cacheServiceProvider.overrideWithValue(testCache),
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
            playbackStateProvider.overrideWith(
              (ref) => Stream<PlaybackState>.empty(),
            ),
            settingsNotifierProvider.overrideWith(
              () => _FakeSettingsNotifier(),
            ),
            vodProvider.overrideWith(_SeriesVodNotifier.new),
            vodFavoritesProvider.overrideWith(
              () => _FakeVodFavoritesNotifier(),
            ),
            seriesEpisodesProvider((
              seriesId: 'series-1',
              sourceId: null,
            )).overrideWith((_) async => _testEpisodeResult),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.fromThemeState(const ThemeState()).theme,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SeriesDetailScreen),
        matchesGoldenFile('goldens/series_detail_compact_episodes.png'),
      );
    },
  );

  testWidgets('SeriesDetailScreen golden — expanded all tabs visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

    final router = GoRouter(
      initialLocation: '/series',
      routes: [
        GoRoute(
          path: '/series',
          builder: (_, _) => const SeriesDetailScreen(series: _testSeries),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          crispyBackendProvider.overrideWithValue(testBackend),
          cacheServiceProvider.overrideWithValue(testCache),
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
          playbackStateProvider.overrideWith(
            (ref) => Stream<PlaybackState>.empty(),
          ),
          settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
          vodProvider.overrideWith(_SeriesVodNotifier.new),
          vodFavoritesProvider.overrideWith(() => _FakeVodFavoritesNotifier()),
          seriesEpisodesProvider((
            seriesId: 'series-1',
            sourceId: null,
          )).overrideWith((_) async => _testEpisodeResult),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SeriesDetailScreen),
      matchesGoldenFile('goldens/series_detail_expanded.png'),
    );
  });
}

// ── Fake notifiers ────────────────────────────────────────────────────────────

class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  @override
  Future<SettingsState> build() async => SettingsState(
    config: const AppConfig(
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
        autoPlay: false,
        defaultAspectRatio: '16:9',
      ),
      theme: ThemeConfig(
        mode: 'dark',
        seedColorHex: '#6750A4',
        useDynamicColor: false,
      ),
      features: FeaturesConfig(
        iptvEnabled: true,
        jellyfinEnabled: false,
        plexEnabled: false,
        embyEnabled: false,
      ),
      cache: CacheConfig(
        epgRefreshIntervalMinutes: 360,
        channelListRefreshIntervalMinutes: 60,
        maxCachedEpgDays: 7,
      ),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _SeriesVodNotifier extends VodNotifier {
  @override
  VodState build() =>
      VodState(items: const [_testSeries], categories: const ['Drama']);
}

class _FakeVodFavoritesNotifier extends VodFavoritesController {
  @override
  Future<Set<String>> build() async => const {};
}
