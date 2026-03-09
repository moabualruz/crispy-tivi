import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/media_server_auth.dart';

void main() {
  // Tests run natively, so the device name comes from Platform.operatingSystem.
  final expectedDevice = () {
    final os = Platform.operatingSystem;
    return '${os[0].toUpperCase()}${os.substring(1)}';
  }();

  group('embyAuthHeader', () {
    test('uses provided deviceId with platform device name', () {
      final header =
          'MediaBrowser Client="CrispyTivi", '
          'Device="$expectedDevice", '
          'DeviceId="my-device-123", '
          'Version="0.1.0"';
      expect(embyAuthHeader('my-device-123'), header);
    });

    test('falls back to kDefaultDeviceId when null', () {
      final header =
          'MediaBrowser Client="CrispyTivi", '
          'Device="$expectedDevice", '
          'DeviceId="$kDefaultDeviceId", '
          'Version="0.1.0"';
      expect(embyAuthHeader(null), header);
    });

    test('contains platform-specific Device name, not hardcoded', () {
      final header = embyAuthHeader('test');
      // Must NOT contain the old hardcoded value.
      expect(header, isNot(contains('Device="CrispyTivi Web"')));
      // Must contain the platform name.
      expect(header, contains('Device="$expectedDevice"'));
    });
  });

  group('toServerType', () {
    test('maps emby to MediaServerType.emby', () {
      expect(toServerType(PlaylistSourceType.emby), MediaServerType.emby);
    });

    test('maps jellyfin to MediaServerType.jellyfin', () {
      expect(
        toServerType(PlaylistSourceType.jellyfin),
        MediaServerType.jellyfin,
      );
    });

    test('throws ArgumentError for unsupported type', () {
      expect(() => toServerType(PlaylistSourceType.m3u), throwsArgumentError);
      expect(
        () => toServerType(PlaylistSourceType.xtream),
        throwsArgumentError,
      );
      expect(() => toServerType(PlaylistSourceType.plex), throwsArgumentError);
    });
  });

  group('kDefaultDeviceId', () {
    test('has expected value', () {
      expect(kDefaultDeviceId, 'crispy_tivi_web');
    });
  });
}
