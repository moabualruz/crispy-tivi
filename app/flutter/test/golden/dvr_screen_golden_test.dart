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
import 'package:crispy_tivi/features/dvr/data/dvr_service.dart';
import 'package:crispy_tivi/features/dvr/domain/entities/recording.dart';
import 'package:crispy_tivi/features/dvr/presentation/screens/recordings_screen.dart';

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

/// Shared reference time for deterministic recording dates.
final _now = DateTime(2026, 3, 10, 12, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.useGoogleFonts = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RecordingsScreen golden — compact Scheduled tab empty state', (
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
          dvrServiceProvider.overrideWith(() => _EmptyDvrNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const RecordingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RecordingsScreen),
      matchesGoldenFile('goldens/dvr_screen_compact_scheduled_empty.png'),
    );
  });

  testWidgets(
    'RecordingsScreen golden — expanded Completed tab with recording cards',
    (tester) async {
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
            dvrServiceProvider.overrideWith(
              () => _SeededCompletedDvrNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.fromThemeState(const ThemeState()).theme,
            home: const RecordingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to the Completed tab (index 2).
      // Use .first to disambiguate when Tab label duplicates exist.
      await tester.tap(find.text('Completed').first);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(RecordingsScreen),
        matchesGoldenFile(
          'goldens/dvr_screen_expanded_completed_recordings.png',
        ),
      );
    },
  );
}

// ── Fake notifiers ────────────────────────────────────────────────────────────

class _EmptyDvrNotifier extends DvrService {
  @override
  Future<DvrState> build() async => const DvrState();
}

class _SeededCompletedDvrNotifier extends DvrService {
  @override
  Future<DvrState> build() async => DvrState(
    recordings: [
      Recording(
        id: 'r1',
        channelName: 'BBC One',
        programName: 'Planet Earth III',
        startTime: _now.subtract(const Duration(hours: 2)),
        endTime: _now.subtract(const Duration(hours: 1)),
        status: RecordingStatus.completed,
        fileSizeBytes: 1024 * 1024 * 512,
        filePath: '/recordings/planet_earth_iii.ts',
      ),
      Recording(
        id: 'r2',
        channelName: 'HBO',
        programName: 'The Last of Us',
        startTime: _now.subtract(const Duration(hours: 5)),
        endTime: _now.subtract(const Duration(hours: 4)),
        status: RecordingStatus.completed,
        fileSizeBytes: 1024 * 1024 * 720,
        filePath: '/recordings/the_last_of_us.ts',
      ),
      Recording(
        id: 'r3',
        channelName: 'Sky Sports',
        programName: 'Premier League Highlights',
        startTime: _now.subtract(const Duration(hours: 8)),
        endTime: _now.subtract(const Duration(hours: 7)),
        status: RecordingStatus.completed,
        fileSizeBytes: 1024 * 1024 * 300,
        filePath: '/recordings/pl_highlights.ts',
      ),
    ],
  );
}
