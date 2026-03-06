import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/media_server_auth.dart';

/// The result of resolving a synthetic media server stream URL.
///
/// Carries the resolved HTTP URL and optional request headers that
/// must be forwarded to the player (e.g. auth tokens).
class ResolvedStream {
  const ResolvedStream({required this.url, this.headers});

  /// The resolved HTTP(S) playback URL.
  final String url;

  /// Optional headers to include in the player HTTP request.
  ///
  /// `null` means no extra headers are needed.
  final Map<String, String>? headers;
}

/// Resolves synthetic media server stream URLs to real HTTP URLs.
///
/// Media server content synced via `MediaServerSyncService` stores
/// synthetic scheme URLs in `VodItem.streamUrl`:
/// - `emby://sourceId/itemId`
/// - `jellyfin://sourceId/itemId`
/// - `plex://sourceId/itemId`
///
/// This class maps those synthetic URLs back to real playback URLs
/// by looking up the source configuration from [_sources].
///
/// Regular `http://` / `https://` URLs pass through as `null`
/// (no resolution needed — play directly).
class StreamUrlResolver {
  /// Creates a [StreamUrlResolver] backed by the given [sources] list.
  ///
  /// [sources] must contain all [PlaylistSource] entries that could
  /// appear as the authority segment of a synthetic URL.
  StreamUrlResolver(this._sources);

  final List<PlaylistSource> _sources;

  /// Resolves a [url] to a [ResolvedStream], or returns `null` for
  /// regular HTTP(S) URLs.
  ///
  /// Throws [StateError] when the source ID encoded in the synthetic
  /// URL is not found in [_sources].
  ///
  /// URI parsing note for synthetic schemes:
  /// - `plex://sourceId/itemId` → `uri.host == 'sourceid'` (Dart lowercases
  ///   the authority), `uri.pathSegments.first == 'itemId'`.
  /// - Same applies to `emby://` and `jellyfin://`.
  /// - Source ID lookup is case-insensitive to handle this transparently.
  Future<ResolvedStream?> resolve(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    return switch (uri.scheme) {
      'http' || 'https' => null,
      'emby' || 'jellyfin' => _resolveEmbyJellyfin(uri),
      'plex' => _resolvePlex(uri),
      _ => null,
    };
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  ResolvedStream _resolveEmbyJellyfin(Uri uri) {
    final sourceId = uri.host;
    final itemId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    final source = _findSource(sourceId);

    final token = source.accessToken ?? '';
    final resolvedUrl =
        '${source.url}/Videos/$itemId/stream'
        '?static=true&api_key=$token';

    return ResolvedStream(
      url: resolvedUrl,
      headers: {'X-Emby-Authorization': embyAuthHeader(source.deviceId)},
    );
  }

  ResolvedStream _resolvePlex(Uri uri) {
    final sourceId = uri.host;
    final itemId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    final source = _findSource(sourceId);

    final token = source.accessToken ?? '';
    final clientId = source.deviceId ?? 'crispy-tivi';
    final resolvedUrl =
        '${source.url}/library/metadata/$itemId'
        '?X-Plex-Token=$token';

    return ResolvedStream(
      url: resolvedUrl,
      headers: {'X-Plex-Token': token, 'X-Plex-Client-Identifier': clientId},
    );
  }

  /// Finds a source by ID, case-insensitively.
  ///
  /// Dart's [Uri] lowercases the authority component, so a synthetic URL
  /// `emby://SRC1/item` yields `uri.host == 'src1'`. Comparing with
  /// [String.toLowerCase] ensures the lookup always succeeds when the
  /// stored [PlaylistSource.id] uses mixed case.
  PlaylistSource _findSource(String sourceId) {
    final lower = sourceId.toLowerCase();
    try {
      return _sources.firstWhere((s) => s.id.toLowerCase() == lower);
    } on StateError {
      throw StateError('Source not found: $sourceId');
    }
  }
}
