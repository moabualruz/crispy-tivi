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
import 'package:crispy_tivi/features/player/data/watch_history_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/watch_history_entry.dart';
import 'package:crispy_tivi/features/recommendations/presentation/providers/recommendation_providers.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/vod/presentation/screens/vod_browser_screen.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.useGoogleFonts = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('VodBrowserScreen golden — movies tab', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
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
          vodProvider.overrideWith(_FakeVodNotifier.new),
          continueWatchingMoviesProvider.overrideWith(
            (ref) async => <WatchHistoryEntry>[],
          ),
          continueWatchingSeriesProvider.overrideWith(
            (ref) async => <WatchHistoryEntry>[],
          ),
          vodRecommendationsProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const VodBrowserScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(VodBrowserScreen),
      matchesGoldenFile('goldens/vod_browser_movies.png'),
    );
  });
}

class _FakeVodNotifier extends VodNotifier {
  @override
  VodState build() {
    return VodState(
      items: [
        VodItem(
          id: '1',
          name: 'The Matrix',
          streamUrl: 'http://test/vod/1',
          type: VodType.movie,
          category: 'Action',
          rating: '8.7',
          year: 1999,
          duration: 136,
          description:
              'A computer hacker learns about '
              'the true nature of reality.',
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
          description:
              'A thief who steals corporate '
              'secrets through dream-sharing.',
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
        VodItem(
          id: '4',
          name: 'Interstellar',
          streamUrl: 'http://test/vod/4',
          type: VodType.movie,
          category: 'Sci-Fi',
          rating: '8.6',
          year: 2014,
          duration: 169,
        ),
      ],
      categories: ['Action', 'Sci-Fi', 'Drama'],
    );
  }
}
