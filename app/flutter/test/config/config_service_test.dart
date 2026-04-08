import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

/// Valid system config JSON matching app_config.json structure.
const _validSystemJson = '''
{
  "appName": "Test Player",
  "appVersion": "0.0.1",
  "api": {
    "baseUrl": "http://test:3000",
    "backendPort": 8080,
    "connectTimeoutMs": 5000,
    "receiveTimeoutMs": 10000,
    "sendTimeoutMs": 5000
  },
  "player": {
    "defaultBufferDurationMs": 3000,
    "autoPlay": false,
    "defaultAspectRatio": "16:9"
  },
  "theme": {
    "mode": "system",
    "seedColorHex": "#FF0000",
    "useDynamicColor": false
  },
  "features": {
    "iptvEnabled": true,
    "jellyfinEnabled": false,
    "plexEnabled": false,
    "embyEnabled": false
  },
  "cache": {
    "epgRefreshIntervalMinutes": 60,
    "channelListRefreshIntervalMinutes": 30,
    "maxCachedEpgDays": 3
  }
}
''';

void main() {
  late CacheService cache;

  setUp(() {
    cache = CacheService(MemoryBackend());
  });

  ConfigService createService({String? systemJson}) {
    return ConfigService(
      assetLoader: (_) async => systemJson ?? _validSystemJson,
      cacheService: cache,
      backend: MemoryBackend(),
    );
  }

  group('ConfigService.load', () {
    test('loads system config from assets and parses '
        'correctly', () async {
      final service = createService();
      final config = await service.load();

      expect(config.appName, 'Test Player');
      expect(config.appVersion, '0.0.1');
      expect(config.api.baseUrl, 'http://test:3000');
      expect(config.api.connectTimeoutMs, 5000);
      expect(config.player.hwdecMode, 'auto');
      expect(config.player.defaultAspectRatio, '16:9');
      expect(config.theme.mode, 'system');
      expect(config.theme.seedColorHex, '#FF0000');
      expect(config.features.iptvEnabled, true);
      expect(config.features.jellyfinEnabled, false);
      expect(config.cache.epgRefreshIntervalMinutes, 60);
    });

    test('caches config on subsequent calls', () async {
      var callCount = 0;
      final service = ConfigService(
        assetLoader: (_) async {
          callCount++;
          return _validSystemJson;
        },
        cacheService: cache,
        backend: MemoryBackend(),
      );

      await service.load();
      await service.load();

      expect(callCount, 1);
    });
  });

  group('ConfigService.setOverride', () {
    test('overrides a top-level value', () async {
      final service = createService();

      await service.setOverride('appName', 'Custom Name');
      final config = await service.load();

      expect(config.appName, 'Custom Name');
    });

    test('overrides a nested value via dot-path', () async {
      final service = createService();

      await service.setOverride('theme.mode', 'dark');
      final config = await service.load();

      expect(config.theme.mode, 'dark');
      // Untouched fields remain from system config.
      expect(config.theme.seedColorHex, '#FF0000');
    });

    test('overrides deeply nested value', () async {
      final service = createService();

      await service.setOverride('api.connectTimeoutMs', 9999);
      final config = await service.load();

      expect(config.api.connectTimeoutMs, 9999);
      // Other API values untouched.
      expect(config.api.baseUrl, 'http://test:3000');
    });

    test('persists overrides across instances', () async {
      final service1 = createService();
      await service1.setOverride('appName', 'Persisted');

      // New instance, same backend.
      final service2 = createService();
      final config = await service2.load();

      expect(config.appName, 'Persisted');
    });
  });

  group('ConfigService.clearOverrides', () {
    test('reverts to system defaults after clearing', () async {
      final service = createService();

      await service.setOverride('appName', 'Modified');
      await service.clearOverrides();
      final config = await service.load();

      expect(config.appName, 'Test Player');
    });
  });
}
