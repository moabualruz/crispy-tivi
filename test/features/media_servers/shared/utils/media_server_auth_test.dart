import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/media_server_auth.dart';

void main() {
  group('embyAuthHeader', () {
    test('uses provided deviceId', () {
      const header =
          'MediaBrowser Client="CrispyTivi", '
          'Device="CrispyTivi Web", '
          'DeviceId="my-device-123", '
          'Version="0.1.0"';
      expect(embyAuthHeader('my-device-123'), header);
    });

    test('falls back to kDefaultDeviceId when null', () {
      const header =
          'MediaBrowser Client="CrispyTivi", '
          'Device="CrispyTivi Web", '
          'DeviceId="$kDefaultDeviceId", '
          'Version="0.1.0"';
      expect(embyAuthHeader(null), header);
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
