import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/channel_providers.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/search/domain/entities/grouped_search_results.dart';
import 'package:crispy_tivi/features/search/domain/entities/search_state.dart';
import 'package:crispy_tivi/features/search/presentation/providers/search_providers.dart';
import 'package:crispy_tivi/features/search/presentation/screens/search_screen.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
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

  testWidgets('SearchScreen golden — compact empty state', (tester) async {
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
          playbackStateProvider.overrideWith(
            (ref) => Stream<PlaybackState>.empty(),
          ),
          searchControllerProvider.overrideWith(() => _EmptySearchNotifier()),
          channelListProvider.overrideWith(_EmptyChannelListNotifier.new),
          vodProvider.overrideWith(_EmptyVodNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SearchScreen),
      matchesGoldenFile('goldens/search_screen_compact_empty.png'),
    );
  });

  testWidgets('SearchScreen golden — expanded with results', (tester) async {
    // Use a taller viewport to avoid overflow in search result rows.
    tester.view.physicalSize = const Size(1280, 1000);
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
          playbackStateProvider.overrideWith(
            (ref) => Stream<PlaybackState>.empty(),
          ),
          searchControllerProvider.overrideWith(() => _SeededSearchNotifier()),
          channelListProvider.overrideWith(_SeededChannelListNotifier.new),
          vodProvider.overrideWith(_SeededVodNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SearchScreen),
      matchesGoldenFile('goldens/search_screen_expanded_results.png'),
    );
  });
}

// ── Fake notifiers ────────────────────────────────────────────────────────────

class _EmptySearchNotifier extends SearchNotifier {
  @override
  SearchState build() => const SearchState();
}

class _SeededSearchNotifier extends SearchNotifier {
  @override
  SearchState build() => const SearchState(
    query: 'action',
    results: GroupedSearchResults(
      channels: [],
      movies: [],
      series: [],
      epgPrograms: [],
    ),
    availableCategories: ['Action', 'Sci-Fi', 'Drama'],
  );
}

class _EmptyChannelListNotifier extends ChannelListNotifier {
  @override
  ChannelListState build() => const ChannelListState();
}

class _SeededChannelListNotifier extends ChannelListNotifier {
  @override
  ChannelListState build() => ChannelListState(
    channels: const [
      Channel(
        id: '1',
        name: 'Action Channel',
        streamUrl: 'http://test/1',
        group: 'Action',
      ),
      Channel(
        id: '2',
        name: 'HBO',
        streamUrl: 'http://test/2',
        group: 'Entertainment',
      ),
    ],
    groups: const ['Action', 'Entertainment'],
  );
}

class _EmptyVodNotifier extends VodNotifier {
  @override
  VodState build() => VodState();
}

class _SeededVodNotifier extends VodNotifier {
  @override
  VodState build() => VodState(
    items: const [
      VodItem(
        id: '10',
        name: 'Action Hero',
        streamUrl: 'http://test/vod/10',
        type: VodType.movie,
        category: 'Action',
        year: 2022,
      ),
      VodItem(
        id: '11',
        name: 'Space Opera',
        streamUrl: 'http://test/vod/11',
        type: VodType.series,
        category: 'Sci-Fi',
        year: 2021,
      ),
    ],
    categories: const ['Action', 'Sci-Fi'],
  );
}
