import 'dart:convert';

/// Pure-Dart Xtream URL builders.
///
/// Synchronous local fallbacks used by both [WsBackend]
/// (sync methods cannot use WebSocket) and [MemoryBackend]
/// (no FFI or WS available).
///
/// Mirrors the Rust functions in
/// `crispy-core::parsers::xtream`.

// ── Xtream URL Builders ───────────────────────────────────────────

/// Build an Xtream player_api.php action URL.
///
/// [paramsJson] is an optional JSON object whose key/value pairs
/// are appended as query parameters (URL-encoded).
String dartBuildXtreamActionUrl({
  required String baseUrl,
  required String username,
  required String password,
  required String action,
  String? paramsJson,
}) {
  final buf =
      StringBuffer()
        ..write(baseUrl)
        ..write('/player_api.php?username=')
        ..write(username)
        ..write('&password=')
        ..write(password)
        ..write('&action=')
        ..write(action);
  if (paramsJson != null && paramsJson.isNotEmpty) {
    try {
      final params = jsonDecode(paramsJson) as Map<String, dynamic>;
      for (final entry in params.entries) {
        buf
          ..write('&')
          ..write(Uri.encodeQueryComponent(entry.key))
          ..write('=')
          ..write(Uri.encodeQueryComponent(entry.value.toString()));
      }
    } catch (_) {
      // Malformed paramsJson — skip extra params silently.
    }
  }
  return buf.toString();
}

/// Build an Xtream stream URL for live/VOD/series streams.
String dartBuildXtreamStreamUrl({
  required String baseUrl,
  required String username,
  required String password,
  required int streamId,
  required String streamType,
  required String extension,
}) =>
    '$baseUrl/$streamType/$username'
    '/$password/$streamId.$extension';

/// Build an Xtream timeshift (catchup) URL.
String dartBuildXtreamCatchupUrl({
  required String baseUrl,
  required String username,
  required String password,
  required int streamId,
  required int startUtc,
  required int durationMinutes,
}) =>
    '$baseUrl/timeshift/$username'
    '/$password/$durationMinutes'
    '/$startUtc/$streamId.ts';
