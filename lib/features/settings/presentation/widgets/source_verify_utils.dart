import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/domain/entities/playlist_source.dart';

/// Verifies connectivity for [type] using the appropriate backend method.
///
/// Returns `null` on success or an error message string on failure.
///
/// - [PlaylistSourceType.m3u]: checks the M3U URL is reachable via HTTP.
/// - [PlaylistSourceType.xtream]: authenticates with [username] / [password].
/// - [PlaylistSourceType.stalkerPortal]: authenticates with [macAddress].
///
/// All other source types are accepted without verification (returns `null`).
Future<String?> verifySourceConnectivity(
  WidgetRef ref,
  PlaylistSourceType type,
  String url, {
  String? username,
  String? password,
  String? macAddress,
}) async {
  try {
    final backend = ref.read(crispyBackendProvider);
    switch (type) {
      case PlaylistSourceType.xtream:
        final ok = await backend.verifyXtreamCredentials(
          baseUrl: url,
          username: username ?? '',
          password: password ?? '',
        );
        if (!ok) return 'Authentication failed. Check credentials.';
      case PlaylistSourceType.m3u:
        final ok = await backend.verifyM3uUrl(url: url);
        if (!ok) return 'Cannot reach M3U URL.';
      case PlaylistSourceType.stalkerPortal:
        final ok = await backend.verifyStalkerPortal(
          baseUrl: url,
          macAddress: macAddress ?? '',
        );
        if (!ok) return 'Portal authentication failed. Check URL and MAC.';
      default:
        break;
    }
  } catch (e) {
    return 'Connection error: $e';
  }
  return null;
}
