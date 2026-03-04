import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/navigation/app_router.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/epg/presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/iptv/application/playlist_sync_service.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/channel_providers.dart';
import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:mocktail/mocktail.dart';

import 'test_data.dart';

/// Default test config matching `assets/config/app_config.json`.
const _testConfigJson = '''
{
  "appName": "CrispyTivi",
  "appVersion": "0.1.0-test",
  "api": {
    "baseUrl": "http://localhost:3000",
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
    "audioPassthroughCodecs": ["ac3", "dts"],
    "hapticFeedbackEnabled": false
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

/// Mock [PlayerService] that avoids MediaKit init.
///
/// MediaKit requires native library initialization which
/// isn't available in integration tests. This mock prevents
/// ProviderExceptions when navigating to the player screen.
class _MockPlayerService extends Mock implements PlayerService {
  @override
  Stream<PlaybackState> get stateStream => Stream<PlaybackState>.empty();
}

/// Fake sync service that populates the cache with
/// comprehensive test data, simulating a successful
/// Xtream API sync without network access.
class FakeSyncService extends PlaylistSyncService {
  // ignore: use_super_parameters
  FakeSyncService(Ref ref) : _localRef = ref, super(ref);

  final Ref _localRef;

  @override
  Future<int> syncAll({bool force = false}) async {
    final cache = _localRef.read(cacheServiceProvider);
    final channels = TestData.sampleChannels;
    final vods = TestData.sampleVodItems;

    // 1. Save to cache (persistence).
    await cache.saveChannels(channels);
    await cache.saveVodItems(vods);
    await cache.saveEpgEntries(TestData.sampleEpg);

    // 2. Push to UI notifiers (display).
    final groups =
        channels
            .map((c) => c.group)
            .whereType<String>()
            .where((g) => g.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    _localRef.read(channelListProvider.notifier).loadChannels(channels, groups);
    _localRef.read(vodProvider.notifier).loadData(vods);

    // 3. Remap EPG entries from tvgId keys to
    //    channel.id keys (matching real sync service).
    //    VirtualEpgGrid looks up by channel.id.
    final rawEpg = TestData.sampleEpg;
    final tvgToId = <String, String>{};
    for (final ch in channels) {
      if (ch.tvgId != null) {
        tvgToId[ch.tvgId!] = ch.id;
      }
    }
    final remappedEpg = <String, List<EpgEntry>>{};
    for (final entry in rawEpg.entries) {
      final channelId = tvgToId[entry.key] ?? entry.key;
      remappedEpg[channelId] = entry.value;
    }

    // 4. Push EPG to UI notifier.
    _localRef
        .read(epgProvider.notifier)
        .loadData(channels: channels, entries: remappedEpg);

    return channels.length + vods.length;
  }
}

/// Seeds a test Xtream source into the cache so profile
/// selection navigates to Home instead of Settings.
///
/// Uses Wizju Mock API — a free, public Xtream mock on
/// Cloudflare Workers. See `.agent/test_credentials.md`.
Future<void> seedTestSource(CacheService cache) async {
  const server = 'https://xtream-codes-mock-api.wizju.com';
  const user = 'test_user';
  const pass = 'test_pass';
  const sourcesKey = 'crispy_tivi_playlist_sources';
  final sourceJson = jsonEncode([
    {
      'id': 'test_xtream_wizju',
      'name': 'Wizju Mock',
      'url': server,
      'type': 'xtream',
      'epgUrl':
          '$server/xmltv.php?'
          'username=$user&'
          'password=$pass',
      'userAgent': null,
      'refreshIntervalMinutes': 60,
      'username': user,
      'password': pass,
      'accessToken': null,
      'deviceId': null,
      'userid': null,
      'macAddress': null,
    },
  ]);
  await cache.setSetting(sourcesKey, sourceJson);
}

/// Builds the complete test app wrapped in a [ProviderScope]
/// with all providers configured for integration testing.
///
/// Pass a pre-configured [backend] and [cache] to
/// pre-populate test data. Otherwise, fresh in-memory
/// instances are used.
Widget createTestApp({CrispyBackend? backend, CacheService? cache}) {
  final testBackend = backend ?? MemoryBackend();
  final testCache = cache ?? CacheService(testBackend);

  return ProviderScope(
    overrides: [
      // Use in-memory backend.
      crispyBackendProvider.overrideWithValue(testBackend),
      cacheServiceProvider.overrideWithValue(testCache),

      // Use test config (avoids rootBundle asset loading).
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

      // Fake sync: populates cache with test data.
      playlistSyncServiceProvider.overrideWith((ref) => FakeSyncService(ref)),

      // Mock player: avoids MediaKit native init.
      playerServiceProvider.overrideWithValue(_MockPlayerService()),

      // Empty playback stream (no native player).
      playbackStateProvider.overrideWith(
        (ref) => Stream<PlaybackState>.empty(),
      ),
    ],
    child: const _IntegrationTestApp(),
  );
}

/// Navigates past profile selection in integration tests.
///
/// Finds the "Default" profile text and taps it, then waits
/// for the app shell to settle. Call after [pumpWidget] and
/// [pumpAndSettle].
Future<void> selectDefaultProfile(WidgetTester tester) async {
  final defaultProfile = find.text('Default');
  if (defaultProfile.evaluate().isNotEmpty) {
    await tester.tap(defaultProfile.first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
}

/// Icon map for navigation tabs. Used by [navigateToTab]
/// to find tabs by icon when text labels are hidden
/// (e.g., collapsed side rail on desktop).
const _tabIcons = <String, IconData>{
  'Home': Icons.home_outlined,
  'TV': Icons.live_tv_outlined,
  'Guide': Icons.calendar_month_outlined,
  'VODs': Icons.movie_outlined,
  'Settings': Icons.settings_outlined,
};

/// Navigates to a navigation tab by [label].
///
/// Tries text first (bottom nav on mobile), then falls
/// back to icon (side rail on desktop where labels are
/// hidden when collapsed).
Future<void> navigateToTab(WidgetTester tester, String label) async {
  // Strategy 1: find by text (bottom navigation bar).
  final textFinder = find.text(label);
  if (textFinder.evaluate().isNotEmpty) {
    await tester.tap(textFinder.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    return;
  }

  // Strategy 2: find by icon (side rail, collapsed).
  final icon = _tabIcons[label];
  if (icon != null) {
    final iconFinder = find.byIcon(icon);
    if (iconFinder.evaluate().isNotEmpty) {
      await tester.tap(iconFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      return;
    }

    // Also try the selected variant.
    final selectedIcons = <String, IconData>{
      'Home': Icons.home,
      'TV': Icons.live_tv,
      'Guide': Icons.calendar_month,
      'VODs': Icons.movie,
      'Settings': Icons.settings,
    };
    final selIcon = selectedIcons[label];
    if (selIcon != null) {
      final selFinder = find.byIcon(selIcon);
      if (selFinder.evaluate().isNotEmpty) {
        await tester.tap(selFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        return;
      }
    }
  }
}

/// Asserts that a navigation tab with [label] is present
/// in the widget tree (by text or icon).
void expectTabExists(String label) {
  final byText = find.text(label);
  final icon = _tabIcons[label];
  final byIcon = icon != null ? find.byIcon(icon) : find.text(label);

  expect(
    byText.evaluate().isNotEmpty || byIcon.evaluate().isNotEmpty,
    isTrue,
    reason:
        'Expected navigation tab "$label" to exist '
        '(by text or icon).',
  );
}

/// Minimal app widget for integration testing.
///
/// Mirrors [CrispyTiviApp] including the startup
/// `syncAll()` call that populates channels and VODs.
class _IntegrationTestApp extends ConsumerStatefulWidget {
  const _IntegrationTestApp();

  @override
  ConsumerState<_IntegrationTestApp> createState() =>
      _IntegrationTestAppState();
}

class _IntegrationTestAppState extends ConsumerState<_IntegrationTestApp> {
  @override
  void initState() {
    super.initState();
    // Mirror CrispyTiviApp: trigger sync on startup
    // so FakeSyncService populates channels + VODs.
    Future.microtask(() {
      ref.read(playlistSyncServiceProvider).syncAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final themeState = ref.watch(themeProvider);
    final router = ref.watch(goRouterProvider);

    return settingsAsync.when(
      loading:
          () => const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
      error:
          (error, stack) => MaterialApp(
            home: Scaffold(body: Center(child: Text('Config error: $error'))),
          ),
      data: (settings) {
        final appTheme = AppTheme.fromThemeState(themeState);
        final themedData = appTheme.theme.copyWith(
          visualDensity: themeState.density.visualDensity,
        );

        return MaterialApp.router(
          title: settings.config.appName,
          debugShowCheckedModeBanner: false,
          theme: themedData,
          darkTheme: themedData,
          themeMode: ThemeMode.dark,
          routerConfig: router,
        );
      },
    );
  }
}
