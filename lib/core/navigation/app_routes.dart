/// All named routes in CrispyTivi.
abstract final class AppRoutes {
  static const String home = '/home';
  static const String tv = '/tv';
  static const String epg = '/epg';
  static const String vod = '/vods';
  static const String vodDetails = '/vods/details';
  static const String dvr = '/dvr';
  static const String settings = '/settings';
  static const String login = '/login';
  static const String profiles = '/profiles';
  static const String onboarding = '/onboarding';
  static const String favorites = '/favorites';
  static const String multiview = '/multiview';
  static const String mediaServers = '/media-servers';
  static const String customSearch = '/search';
  static const String series = '/series';
  static const String jellyfinLogin = '/jellyfin/login';
  static const String jellyfinQuickConnect = '/jellyfin/quick-connect';
  static const String jellyfinHome = '/jellyfin/home';
  static const String embyLogin = '/emby/login';
  static const String embyHome = '/emby/home';
  static const String plexLogin = '/plex/login';
  static const String plexHome = '/plex/home';
  static const String mediaServerDetails = '/media-servers/details';
  static const String profileManagement = '/settings/profiles';
  static const String seriesDetail = '/series/detail';
  static const String cloudBrowser = '/cloud-browser';

  // ── Jellyfin sub-routes ───────────────────────────────────────────────

  /// Jellyfin library route. Use [jellyfinLibrary] to build a concrete path.
  static const String jellyfinLibraryBase = '/jellyfin/library';

  /// Builds the Jellyfin library route for [itemId] with an optional [title].
  static String jellyfinLibrary(String itemId, {String? title}) {
    final base = '$jellyfinLibraryBase/$itemId';
    return title != null ? '$base?title=${Uri.encodeComponent(title)}' : base;
  }

  /// Jellyfin series route. Use [jellyfinSeries] to build a concrete path.
  static const String jellyfinSeriesBase = '/jellyfin/series';

  /// Builds the Jellyfin series navigation route for [seriesId].
  static String jellyfinSeries(String seriesId, {String? title}) {
    final base = '$jellyfinSeriesBase/$seriesId';
    return title != null ? '$base?title=${Uri.encodeComponent(title)}' : base;
  }

  // ── Emby sub-routes ───────────────────────────────────────────────────

  /// Emby library route. Use [embyLibrary] to build a concrete path.
  static const String embyLibraryBase = '/emby/library';

  /// Builds the Emby library route for [itemId] with an optional [title].
  static String embyLibrary(String itemId, {String? title}) {
    final base = '$embyLibraryBase/$itemId';
    return title != null ? '$base?title=${Uri.encodeComponent(title)}' : base;
  }

  /// Emby series route. Use [embySeries] to build a concrete path.
  static const String embySeriesBase = '/emby/series';

  /// Builds the Emby series navigation route for [seriesId].
  static String embySeries(String seriesId, {String? title}) {
    final base = '$embySeriesBase/$seriesId';
    return title != null ? '$base?title=${Uri.encodeComponent(title)}' : base;
  }

  // ── Plex sub-routes ───────────────────────────────────────────────────

  /// Plex library route. Use [plexLibrary] to build a concrete path.
  static const String plexLibraryBase = '/plex/library';

  /// Plex children route (seasons/episodes). Use [plexChildren] to build.
  static const String plexChildrenBase = '/plex/children';

  /// Builds the Plex library route for [libraryId] with an optional [title].
  static String plexLibrary(String libraryId, {String? title}) {
    final base = '$plexLibraryBase/$libraryId';
    return title != null ? '$base?title=${Uri.encodeComponent(title)}' : base;
  }

  /// Builds the Plex children route for [itemId] with an optional [title].
  static String plexChildren(String itemId, {String? title}) {
    final base = '$plexChildrenBase/$itemId';
    return title != null ? '$base?title=${Uri.encodeComponent(title)}' : base;
  }
}
