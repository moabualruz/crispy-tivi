/// Re-exports for media-server presentation layer.
///
/// Providers in [iptv/presentation/] that orchestrate Plex, Emby, and
/// Jellyfin sync must import from this file instead of reaching directly
/// into data/ layers (DIP / ISP compliance).
export '../../data/media_server_api_client.dart' show MediaServerApiClient;
export '../../data/media_server_dio_factory.dart'
    show createEmbyJellyfinSyncDio, createPlexSyncDio;
export '../../data/media_server_source.dart' show MediaServerSource;
export '../../../plex/data/datasources/plex_api_client.dart'
    show PlexApiClient;
