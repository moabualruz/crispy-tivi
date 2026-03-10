import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/epg/presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/favorites/presentation/providers/favorites_controller.dart';
import 'package:crispy_tivi/features/home/presentation/providers/home_providers.dart';
import 'package:crispy_tivi/features/home/presentation/screens/home_screen.dart';
import 'package:crispy_tivi/features/iptv/application/playlist_sync_service.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/channel_providers.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/recommendations/presentation/providers/recommendation_providers.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_favorites_provider.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/player/data/watch_history_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/watch_history_entry.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.useGoogleFonts = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen golden — expanded 1280x800 with sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/favorites',
          builder: (_, _) => const Scaffold(body: Text('Favorites')),
        ),
        GoRoute(
          path: '/search',
          builder: (_, _) => const Scaffold(body: Text('Search')),
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
          playlistSyncServiceProvider.overrideWith(
            (ref) => _NoOpSyncService(ref),
          ),
          vodProvider.overrideWith(_SeededVodNotifier.new),
          vodFavoritesProvider.overrideWith(() => _FakeVodFavoritesNotifier()),
          channelListProvider.overrideWith(_SeededChannelListNotifier.new),
          epgProvider.overrideWith(_EmptyEpgNotifier.new),
          favoritesControllerProvider.overrideWith(
            () => _EmptyFavoritesNotifier(),
          ),
          recentChannelsProvider.overrideWith((ref) async => const []),
          favoriteChannelsProvider.overrideWith((ref) async => const []),
          continueWatchingMoviesProvider.overrideWith(
            (ref) async => const <WatchHistoryEntry>[],
          ),
          continueWatchingSeriesProvider.overrideWith(
            (ref) async => const <WatchHistoryEntry>[],
          ),
          vodRecommendationsProvider.overrideWithValue(const []),
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
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_screen_expanded.png'),
    );
  });
}

// ── Fake notifiers ────────────────────────────────────────────────────────────

class _NoOpSyncService extends PlaylistSyncService {
  _NoOpSyncService(super.ref);

  @override
  Future<int> syncAll({bool force = false}) async => 0;
}

class _SeededVodNotifier extends VodNotifier {
  @override
  VodState build() => VodState(
    items: const [
      VodItem(
        id: '1',
        name: 'The Matrix',
        streamUrl: 'http://test/vod/1',
        type: VodType.movie,
        category: 'Action',
        rating: '8.7',
        year: 1999,
        duration: 136,
        description: 'A computer hacker learns the true nature of reality.',
      ),
      VodItem(
        id: '2',
        name: 'Inception',
        streamUrl: 'http://test/vod/2',
        type: VodType.movie,
        category: 'Sci-Fi',
        rating: '8.8',
        year: 2010,
        duration: 148,
      ),
      VodItem(
        id: '3',
        name: 'Breaking Bad',
        streamUrl: 'http://test/vod/3',
        type: VodType.series,
        category: 'Drama',
        rating: '9.5',
        year: 2008,
      ),
    ],
    categories: const ['Action', 'Sci-Fi', 'Drama'],
  );
}

class _SeededChannelListNotifier extends ChannelListNotifier {
  @override
  ChannelListState build() => ChannelListState(
    channels: const [
      Channel(
        id: 'ch1',
        name: 'BBC News',
        streamUrl: 'http://test/ch1',
        group: 'News',
      ),
      Channel(
        id: 'ch2',
        name: 'CNN',
        streamUrl: 'http://test/ch2',
        group: 'News',
      ),
      Channel(
        id: 'ch3',
        name: 'ESPN',
        streamUrl: 'http://test/ch3',
        group: 'Sports',
      ),
    ],
    groups: const ['News', 'Sports'],
  );
}

class _EmptyEpgNotifier extends EpgNotifier {
  @override
  EpgState build() => const EpgState();
}

class _EmptyFavoritesNotifier extends FavoritesController {
  @override
  Future<List<Channel>> build() async => const [];
}

class _FakeVodFavoritesNotifier extends VodFavoritesController {
  @override
  Future<Set<String>> build() async => const {};
}
