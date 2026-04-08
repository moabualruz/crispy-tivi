import 'package:meta/meta.dart';

/// Type of playlist source.
enum PlaylistSourceType {
  /// Standard M3U/M3U8 file (URL or local path).
  m3u,

  /// Xtream Codes API provider.
  xtream,

  /// Stalker Portal (MAG middleware) provider.
  stalkerPortal,

  /// Jellyfin Media Server.
  jellyfin,

  /// Emby Media Server.
  emby,

  /// Plex Media Server.
  plex,
}

/// A configured IPTV playlist source.
///
/// Domain entity — represents a user-added M3U URL or
/// Xtream Codes provider with its associated EPG URL.
@immutable
class PlaylistSource {
  const PlaylistSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.epgUrl,
    this.userAgent,
    this.refreshIntervalMinutes = 60,
    this.username,
    this.password,
    this.accessToken,
    this.deviceId,
    this.userId,
    this.macAddress,
    this.acceptSelfSigned = false,
  });

  /// Unique identifier.
  final String id;

  /// User-given display name.
  final String name;

  /// M3U URL/path or Xtream base URL.
  final String url;

  /// Source type.
  final PlaylistSourceType type;

  /// Optional XMLTV EPG URL.
  final String? epgUrl;

  /// Custom User-Agent to use when fetching.
  final String? userAgent;

  /// Background refresh interval in minutes.
  final int refreshIntervalMinutes;

  /// Xtream username (only for [PlaylistSourceType.xtream]).
  final String? username;

  /// Xtream password (only for [PlaylistSourceType.xtream]).
  final String? password;

  /// Jellyfin Access Token.
  final String? accessToken;

  /// Device ID used for authentication.
  final String? deviceId;

  /// User ID on the server.
  final String? userId;

  /// MAC address for Stalker Portal authentication.
  ///
  /// Format: `XX:XX:XX:XX:XX:XX` (uppercase hex with colons).
  /// Only used for [PlaylistSourceType.stalkerPortal].
  final String? macAddress;

  /// Whether to accept self-signed TLS certificates for this source.
  ///
  /// When `true`, Rust will use `danger_accept_invalid_certs(true)` for
  /// HTTP requests to this source. Only enable for trusted local servers.
  final bool acceptSelfSigned;

  PlaylistSource copyWith({
    String? id,
    String? name,
    String? url,
    PlaylistSourceType? type,
    String? epgUrl,
    String? userAgent,
    int? refreshIntervalMinutes,
    String? username,
    String? password,
    String? accessToken,
    String? deviceId,
    String? userId,
    String? macAddress,
    bool? acceptSelfSigned,
  }) {
    return PlaylistSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      epgUrl: epgUrl ?? this.epgUrl,
      userAgent: userAgent ?? this.userAgent,
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      username: username ?? this.username,
      password: password ?? this.password,
      accessToken: accessToken ?? this.accessToken,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      macAddress: macAddress ?? this.macAddress,
      acceptSelfSigned: acceptSelfSigned ?? this.acceptSelfSigned,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistSource &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  /// Generates a unique source ID based on current timestamp.
  static String generateId() => 'src_${DateTime.now().millisecondsSinceEpoch}';

  /// Builds the Xtream Codes XMLTV EPG URL from server URL and credentials.
  static String buildXtreamEpgUrl(
    String url,
    String username,
    String password,
  ) {
    final parsed = Uri.tryParse(url);
    final base =
        parsed != null
            ? '${parsed.scheme}://${parsed.host}'
                '${parsed.hasPort ? ":${parsed.port}" : ""}'
            : url;
    return '$base/xmltv.php?username=$username&password=$password';
  }

  @override
  String toString() => 'PlaylistSource($name, type=$type)';
}
