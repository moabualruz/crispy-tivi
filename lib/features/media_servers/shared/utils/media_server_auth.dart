import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';

/// Fallback device ID used when no device-specific ID is configured.
///
/// Emby/Jellyfin use this to track sessions per device. For production
/// this should be replaced with a platform-generated UUID stored in
/// persistent settings (see [PlaylistSource.deviceId]).
const String kDefaultDeviceId = 'crispy_tivi_web';

/// Builds the shared Emby/Jellyfin authorization header value.
///
/// The resulting string follows the MediaBrowser format required by
/// both Emby and Jellyfin servers:
/// `MediaBrowser Client="...", Device="...", DeviceId="...", Version="..."`
String embyAuthHeader(String? deviceId) =>
    'MediaBrowser Client="CrispyTivi", Device="CrispyTivi Web", '
    'DeviceId="${deviceId ?? kDefaultDeviceId}", Version="0.1.0"';

/// Maps [PlaylistSourceType] to the corresponding [MediaServerType].
///
/// Throws [ArgumentError] for source types that have no server mapping
/// (e.g. [PlaylistSourceType.m3u], [PlaylistSourceType.xtream]).
MediaServerType toServerType(PlaylistSourceType type) => switch (type) {
  PlaylistSourceType.emby => MediaServerType.emby,
  PlaylistSourceType.jellyfin => MediaServerType.jellyfin,
  _ => throw ArgumentError('Unsupported server type: $type'),
};
