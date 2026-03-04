import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/navigation/app_shell.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';

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

  testWidgets('AppShell golden — side navigation at '
      '1920x1080', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Center(child: Text('Home Content')),
            ),
            GoRoute(
              path: '/tv',
              builder: (_, _) => const Center(child: Text('TV Content')),
            ),
            GoRoute(
              path: '/epg',
              builder: (_, _) => const Center(child: Text('EPG Content')),
            ),
            GoRoute(
              path: '/vods',
              builder: (_, _) => const Center(child: Text('VOD Content')),
            ),
            GoRoute(
              path: '/series',
              builder: (_, _) => const Center(child: Text('Series Content')),
            ),
            GoRoute(
              path: '/dvr',
              builder: (_, _) => const Center(child: Text('DVR Content')),
            ),
            GoRoute(
              path: '/favorites',
              builder: (_, _) => const Center(child: Text('Favorites Content')),
            ),
            GoRoute(
              path: '/search',
              builder: (_, _) => const Center(child: Text('Search Content')),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, _) => const Center(child: Text('Settings Content')),
            ),
          ],
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
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('goldens/app_shell_side_nav.png'),
    );
  });
}
