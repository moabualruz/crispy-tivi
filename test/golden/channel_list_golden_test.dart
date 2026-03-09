import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/epg/presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/iptv/application/playlist_sync_service.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/channel_providers.dart';
import 'package:crispy_tivi/features/iptv/presentation/screens/channel_list_screen.dart';

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

  testWidgets('ChannelListScreen golden — groups view', (tester) async {
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
          playlistSyncServiceProvider.overrideWith(
            (ref) => _NoOpSyncService(ref),
          ),
          channelListProvider.overrideWith(_FakeChannelListNotifier.new),
          epgProvider.overrideWith(_FakeEpgNotifier.new),
          settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const ChannelListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChannelListScreen),
      matchesGoldenFile('goldens/channel_list_groups.png'),
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
  EpgState build() => const EpgState();
}

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
        autoPlay: true,
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

class _FakeChannelListNotifier extends ChannelListNotifier {
  @override
  ChannelListState build() {
    return ChannelListState(
      channels: const [
        Channel(
          id: '1',
          name: 'BBC News',
          streamUrl: 'http://test/1',
          group: 'News',
        ),
        Channel(
          id: '2',
          name: 'CNN International',
          streamUrl: 'http://test/2',
          group: 'News',
        ),
        Channel(
          id: '3',
          name: 'ESPN',
          streamUrl: 'http://test/3',
          group: 'Sports',
        ),
        Channel(
          id: '4',
          name: 'Sky Sports',
          streamUrl: 'http://test/4',
          group: 'Sports',
        ),
        Channel(
          id: '5',
          name: 'HBO',
          streamUrl: 'http://test/5',
          group: 'Entertainment',
        ),
        Channel(
          id: '6',
          name: 'Netflix Originals',
          streamUrl: 'http://test/6',
          group: 'Entertainment',
        ),
      ],
      groups: const ['News', 'Sports', 'Entertainment'],
      showingGroupsView: true,
    );
  }
}
