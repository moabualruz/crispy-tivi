/// Keys used in [MediaItem.metadata] to identify the data source.
abstract final class SearchSourceKey {
  /// IPTV live channel source.
  static const String iptv = 'iptv';

  /// IPTV VOD source.
  static const String iptvVod = 'iptv_vod';

  /// IPTV EPG program source.
  static const String iptvEpg = 'iptv_epg';

  /// Jellyfin media server source.
  static const String jellyfin = 'jellyfin';

  /// Emby media server source.
  static const String emby = 'emby';

  /// Plex media server source.
  static const String plex = 'plex';
}
