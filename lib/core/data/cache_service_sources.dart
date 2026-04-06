part of 'cache_service.dart';

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Format [DateTime] as a NaiveDateTime string for
/// Rust serde.
///
/// Delegates to [toNaiveDateTime] in
/// `date_format_utils.dart`.
String _toNaiveDateTime(DateTime dt) => toNaiveDateTime(dt);

/// Parse a NaiveDateTime string (no timezone) as UTC.
///
/// Delegates to [parseNaiveUtc] in
/// `date_format_utils.dart`.
DateTime _parseNaiveUtc(String s) => parseNaiveUtc(s);

/// Parses a [DateTime] from a map value that may
/// be a [String], [DateTime], or null. Treats
/// timezone-less strings as UTC (NaiveDateTime
/// round-trip from Rust).
DateTime? parseMapDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    return dt.isUtc
        ? dt
        : DateTime.utc(
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
          dt.millisecond,
          dt.microsecond,
        );
  }
  return null;
}

// ── Source converters ────────────────────────────────────────────────────────

/// Converts a [PlaylistSource] entity to a backend
/// map matching the Rust `Source` struct fields.
Map<String, dynamic> sourceToMap(PlaylistSource s) => {
  'id': s.id,
  'name': s.name,
  'source_type': _sourceTypeToRust(s.type),
  'url': s.url,
  'username': s.username,
  'password': s.password,
  'access_token': s.accessToken,
  'device_id': s.deviceId,
  'user_id': s.userId,
  'mac_address': s.macAddress,
  'epg_url': s.epgUrl,
  'user_agent': s.userAgent,
  'refresh_interval_minutes': s.refreshIntervalMinutes,
  'accept_self_signed': s.acceptSelfSigned,
  'enabled': true,
  'sort_order': 0,
};

/// Converts a backend map to a [PlaylistSource].
PlaylistSource mapToSource(Map<String, dynamic> m) {
  return PlaylistSource(
    id: m['id'] as String,
    name: m['name'] as String,
    url: m['url'] as String,
    type: _parseSourceType(m['source_type'] as String? ?? 'm3u'),
    epgUrl: m['epg_url'] as String?,
    userAgent: m['user_agent'] as String?,
    refreshIntervalMinutes: (m['refresh_interval_minutes'] as int?) ?? 60,
    username: m['username'] as String?,
    password: m['password'] as String?,
    accessToken: m['access_token'] as String?,
    deviceId: m['device_id'] as String?,
    userId: m['user_id'] as String?,
    macAddress: m['mac_address'] as String?,
    acceptSelfSigned: m['accept_self_signed'] as bool? ?? false,
  );
}

// ── Source type serialization helpers ───────────────────────────────────────

/// Maps Dart [PlaylistSourceType] to the Rust serialized string.
///
/// Rust uses "stalker" for the Stalker portal; Dart uses "stalkerPortal".
String _sourceTypeToRust(PlaylistSourceType t) => switch (t) {
  PlaylistSourceType.stalkerPortal => 'stalker',
  _ => t.name,
};

/// Maps a Rust source type string to Dart [PlaylistSourceType].
PlaylistSourceType _parseSourceType(String s) => switch (s) {
  'stalker' => PlaylistSourceType.stalkerPortal,
  _ => PlaylistSourceType.values.firstWhere(
    (e) => e.name == s,
    orElse: () => PlaylistSourceType.m3u,
  ),
};

// ── Providers ────────────────────────────────────────────────────────────────

/// Backend provider — platform-selected.
/// Override this in main() with FfiBackend or
/// WsBackend.
final crispyBackendProvider = Provider<CrispyBackend>(
  (ref) => throw UnimplementedError('Override crispyBackendProvider in main()'),
);

/// Riverpod provider for [CacheService].
final cacheServiceProvider = Provider<CacheService>((ref) {
  final backend = ref.watch(crispyBackendProvider);
  return CacheService(backend);
});
