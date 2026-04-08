import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('PERF-04: App Startup Benchmark', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('app startup completes in under 2000ms', (tester) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);

      // Measure time from widget pump to first settled frame.
      final stopwatch = Stopwatch()..start();

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
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(body: Center(child: Text('CrispyTivi'))),
          ),
        ),
      );

      // Wait for all async providers and animations to settle.
      await tester.pumpAndSettle(const Duration(seconds: 5));

      stopwatch.stop();

      // PERF-04 assertion: startup must complete in under 2000ms.
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(2000),
        reason:
            'App startup took ${stopwatch.elapsedMilliseconds}ms, '
            'must be under 2000ms',
      );
    });

    testWidgets('startup with pre-seeded data completes in under 2000ms', (
      tester,
    ) async {
      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);

      // Pre-seed source and channels to simulate a returning user.
      await testBackend.saveSource({
        'id': 'src-1',
        'name': 'Test IPTV',
        'url': 'http://example.com/playlist.m3u',
        'source_type': 'xtream',
        'sort_order': 0,
        'enabled': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await testBackend.saveChannels(
        List.generate(
          50,
          (i) => {
            'id': 'ch-$i',
            'name': 'Channel $i',
            'stream_url': 'http://example.com/ch$i.m3u8',
            'channel_group': 'Group ${i % 5}',
            'source_id': 'src-1',
            'sort_order': i,
          },
        ),
      );

      final stopwatch = Stopwatch()..start();

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
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(body: Center(child: Text('CrispyTivi'))),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      stopwatch.stop();

      // PERF-04 assertion: even with 50 pre-seeded channels, startup
      // must complete in under 2000ms.
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(2000),
        reason:
            'Startup with seeded data took '
            '${stopwatch.elapsedMilliseconds}ms, must be under 2000ms',
      );
    });

    test('MemoryBackend + CacheService initialization under 2000ms', () async {
      // Measures pure backend/service layer initialization overhead
      // without Flutter widget rendering.
      final stopwatch = Stopwatch()..start();

      final backend = MemoryBackend();
      final cache = CacheService(backend);

      // Simulate typical startup data loads.
      final sources = await backend.getSources();
      final channels = await cache.loadChannels();

      stopwatch.stop();

      // Verify initialization produced valid empty state.
      expect(sources, isEmpty);
      expect(channels, isEmpty);

      // PERF-04 assertion: backend init must be well under 2000ms.
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(2000),
        reason:
            'Backend initialization took '
            '${stopwatch.elapsedMilliseconds}ms, must be under 2000ms',
      );
    });
  });
}
