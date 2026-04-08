import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/favorites/data/favorites_history_service.dart';
import 'package:crispy_tivi/features/favorites/presentation/providers/favorites_controller.dart';
import 'package:crispy_tivi/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/channel_providers.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_favorites_provider.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';

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

  testWidgets('HistoryScreen golden — compact Tab 0 My Favorites with items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

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
          settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
          playbackStateProvider.overrideWith(
            (ref) => Stream<PlaybackState>.empty(),
          ),
          favoritesHistoryProvider.overrideWith(
            () => _FavoritesEmptyHistoryNotifier(),
          ),
          favoritesControllerProvider.overrideWith(
            () => _FavoritesWithChannelsNotifier(),
          ),
          channelListProvider.overrideWith(_SeededChannelListNotifier.new),
          vodProvider.overrideWith(_FavVodNotifier.new),
          vodFavoritesProvider.overrideWith(() => _FakeVodFavoritesNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HistoryScreen),
      matchesGoldenFile('goldens/favorites_screen_compact_my_list.png'),
    );
  });

  testWidgets('HistoryScreen golden — expanded Tab 1 Recently Watched', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

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
          settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
          playbackStateProvider.overrideWith(
            (ref) => Stream<PlaybackState>.empty(),
          ),
          favoritesHistoryProvider.overrideWith(
            () => _FavoritesWithHistoryNotifier(),
          ),
          favoritesControllerProvider.overrideWith(
            () => _FavoritesEmptyChannelsNotifier(),
          ),
          channelListProvider.overrideWith(_SeededChannelListNotifier.new),
          vodProvider.overrideWith(_EmptyVodNotifier.new),
          vodFavoritesProvider.overrideWith(() => _FakeVodFavoritesNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the Recently Watched tab (index 1).
    await tester.tap(find.text('Recently Watched'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HistoryScreen),
      matchesGoldenFile('goldens/favorites_screen_expanded_recent.png'),
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

class _FavoritesEmptyHistoryNotifier extends FavoritesHistoryService {
  @override
  FavoritesHistoryState build() => const FavoritesHistoryState();
}

class _FavoritesWithHistoryNotifier extends FavoritesHistoryService {
  @override
  FavoritesHistoryState build() => const FavoritesHistoryState(
    recentlyWatched: [
      Channel(
        id: '1',
        name: 'BBC News',
        streamUrl: 'http://test/1',
        group: 'News',
      ),
      Channel(
        id: '2',
        name: 'Sky Sports',
        streamUrl: 'http://test/2',
        group: 'Sports',
      ),
      Channel(
        id: '3',
        name: 'HBO',
        streamUrl: 'http://test/3',
        group: 'Entertainment',
      ),
    ],
  );
}

class _FavoritesWithChannelsNotifier extends FavoritesController {
  @override
  Future<List<Channel>> build() async => const [
    Channel(
      id: '1',
      name: 'BBC News',
      streamUrl: 'http://test/1',
      group: 'News',
      isFavorite: true,
    ),
    Channel(
      id: '2',
      name: 'ESPN',
      streamUrl: 'http://test/2',
      group: 'Sports',
      isFavorite: true,
    ),
  ];
}

class _FavoritesEmptyChannelsNotifier extends FavoritesController {
  @override
  Future<List<Channel>> build() async => const [];
}

class _SeededChannelListNotifier extends ChannelListNotifier {
  @override
  ChannelListState build() => ChannelListState(
    channels: const [
      Channel(
        id: '1',
        name: 'BBC News',
        streamUrl: 'http://test/1',
        group: 'News',
      ),
      Channel(
        id: '2',
        name: 'ESPN',
        streamUrl: 'http://test/2',
        group: 'Sports',
      ),
    ],
    groups: const ['News', 'Sports'],
  );
}

class _FavVodNotifier extends VodNotifier {
  @override
  VodState build() => VodState(
    items: [
      const VodItem(
        id: '10',
        name: 'The Matrix',
        streamUrl: 'http://test/vod/10',
        type: VodType.movie,
        category: 'Action',
        isFavorite: true,
      ),
    ],
    categories: const ['Action'],
  );
}

class _EmptyVodNotifier extends VodNotifier {
  @override
  VodState build() => VodState();
}

class _FakeVodFavoritesNotifier extends VodFavoritesController {
  @override
  Future<Set<String>> build() async => const {'10'};
}
