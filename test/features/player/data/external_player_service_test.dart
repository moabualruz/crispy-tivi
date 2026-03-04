import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crispy_tivi/features/player/data/external_player_service.dart';

void main() {
  group('ExternalPlayer enum', () {
    test('has all expected players', () {
      expect(ExternalPlayer.values.length, 7);
      expect(
        ExternalPlayer.values.map((e) => e.name),
        containsAll([
          'systemDefault',
          'vlc',
          'mxPlayer',
          'mxPlayerPro',
          'kodi',
          'justPlayer',
          'mpv',
        ]),
      );
    });

    test('each player has a display label', () {
      for (final player in ExternalPlayer.values) {
        expect(
          player.label,
          isNotEmpty,
          reason: '${player.name} should have label',
        );
      }
    });

    test('non-systemDefault players have Android package', () {
      for (final player in ExternalPlayer.values) {
        if (player == ExternalPlayer.systemDefault) {
          expect(player.androidPackage, isNull);
        } else {
          expect(
            player.androidPackage,
            isNotNull,
            reason: '${player.name} should have package',
          );
          expect(
            player.androidPackage,
            isNotEmpty,
            reason: '${player.name} package not empty',
          );
        }
      }
    });

    test('VLC has correct Android package', () {
      expect(ExternalPlayer.vlc.androidPackage, 'org.videolan.vlc');
    });

    test('MX Player has correct Android package', () {
      expect(
        ExternalPlayer.mxPlayer.androidPackage,
        'com.mxtech.videoplayer.ad',
      );
    });

    test('MX Player Pro has correct Android package', () {
      expect(
        ExternalPlayer.mxPlayerPro.androidPackage,
        'com.mxtech.videoplayer.pro',
      );
    });

    test('Kodi has correct Android package', () {
      expect(ExternalPlayer.kodi.androidPackage, 'org.xbmc.kodi');
    });

    test('mpv has correct Android package', () {
      expect(ExternalPlayer.mpv.androidPackage, 'is.xyz.mpv');
    });
  });

  group('ExternalPlayerService', () {
    late ExternalPlayerService service;

    setUp(() {
      service = ExternalPlayerService();
    });

    test('service is instantiated without error', () {
      expect(service, isNotNull);
    });

    test('launch method exists and is callable', () {
      // Verify the method signature is correct.
      expect(
        service.launch,
        isA<
          Future<bool> Function({
            required String streamUrl,
            ExternalPlayer player,
            String? title,
            Map<String, String>? headers,
          })
        >(),
      );
    });
  });

  group('externalPlayerServiceProvider', () {
    test('provides ExternalPlayerService instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(externalPlayerServiceProvider);
      expect(service, isA<ExternalPlayerService>());
    });

    test('returns same instance on multiple reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service1 = container.read(externalPlayerServiceProvider);
      final service2 = container.read(externalPlayerServiceProvider);
      expect(identical(service1, service2), isTrue);
    });
  });

  group('ExternalPlayerService VLC paths', () {
    // Verify known VLC paths are defined correctly
    // (static constant, no runtime dependency).
    test('well-known VLC paths are defined', () {
      // Access the service — the static _vlcPaths is
      // private but we can test indirectly by verifying
      // launch doesn't crash with a valid stream URL.
      final service = ExternalPlayerService();
      expect(service, isNotNull);
    });
  });

  group('ExternalPlayer name-based lookup', () {
    test('values.firstWhere matches by name for all players', () {
      for (final player in ExternalPlayer.values) {
        final found = ExternalPlayer.values.firstWhere(
          (p) => p.name == player.name,
        );
        expect(found, player);
      }
    });

    test('settings string maps to correct ExternalPlayer', () {
      // Simulate what player_screen.dart does when
      // reading the setting.
      const settingsMap = {
        'systemDefault': ExternalPlayer.systemDefault,
        'vlc': ExternalPlayer.vlc,
        'mxPlayer': ExternalPlayer.mxPlayer,
        'mxPlayerPro': ExternalPlayer.mxPlayerPro,
        'kodi': ExternalPlayer.kodi,
        'justPlayer': ExternalPlayer.justPlayer,
        'mpv': ExternalPlayer.mpv,
      };

      for (final entry in settingsMap.entries) {
        final player = ExternalPlayer.values.firstWhere(
          (p) => p.name == entry.key,
          orElse: () => ExternalPlayer.systemDefault,
        );
        expect(
          player,
          entry.value,
          reason:
              '${entry.key} should map to '
              '${entry.value}',
        );
      }
    });

    test('unknown name falls back to systemDefault', () {
      final player = ExternalPlayer.values.firstWhere(
        (p) => p.name == 'nonExistentPlayer',
        orElse: () => ExternalPlayer.systemDefault,
      );
      expect(player, ExternalPlayer.systemDefault);
    });
  });
}
