import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/constants.dart';
import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/exceptions/media_source_exception.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';

import '../../data/datasources/plex_api_client.dart';
import '../../domain/plex_source.dart';

// ── Dependency Injection ──────────────────────────────────────────────

/// Provider for the active Plex Source.
final plexSourceProvider = Provider<PlexSource?>((ref) {
  final settings = ref.watch(settingsNotifierProvider).asData?.value;
  if (settings == null) return null;

  try {
    final config = settings.sources.firstWhere(
      (s) => s.type == PlaylistSourceType.plex,
    );

    final dio = Dio();
    ref.onDispose(dio.close);
    final apiClient = PlexApiClient(dio: dio);

    return PlexSource(
      apiClient: apiClient,
      serverUrl: config.url,
      accessToken: config.accessToken ?? '',
      clientIdentifier: 'crispy-tivi-web',
      serverName: config.name,
      serverId: config.id,
    );
  } catch (e) {
    return null;
  }
});

// ── Library State ─────────────────────────────────────────────────────

/// Fetches root libraries.
final plexLibrariesProvider = FutureProvider<List<MediaItem>>((ref) async {
  final source = ref.watch(plexSourceProvider);
  if (source == null) return [];
  return source.getLibrary(null);
});

/// Fetches items within a library.
final plexItemsProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  parentId,
) async {
  final source = ref.watch(plexSourceProvider);
  if (source == null) return [];
  return source.getLibrary(parentId);
});

/// Resolves playback URL for an item.
final plexStreamUrlProvider = FutureProvider.family<String, String>((
  ref,
  itemId,
) async {
  final source = ref.read(plexSourceProvider);
  if (source == null) {
    throw MediaSourceException.server(message: 'No Plex source connected');
  }
  return source.getStreamUrl(itemId);
});

/// Fetches children of an item (seasons of a show, episodes of a season).
final plexChildrenProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  itemId,
) async {
  final source = ref.watch(plexSourceProvider);
  if (source == null) return [];
  return source.getChildren(itemId);
});

// ── Paginated Library State ──────────────────────────────────────────

/// Provider for paginated Plex library items.
///
/// Returns the initial page of items with pagination metadata.
final plexPaginatedItemsProvider = FutureProvider.autoDispose
    .family<PaginatedResult<MediaItem>, String>((ref, parentId) async {
      final source = ref.watch(plexSourceProvider);
      if (source == null) {
        return PaginatedResult.empty();
      }

      return source.getLibraryPaginated(
        parentId,
        startIndex: 0,
        limit: kMediaServerPageSize,
      );
    });

/// Provider for paginated Plex children items (seasons/episodes).
///
/// Returns the initial page of children with pagination metadata.
final plexPaginatedChildrenProvider = FutureProvider.autoDispose
    .family<PaginatedResult<MediaItem>, String>((ref, itemId) async {
      final source = ref.watch(plexSourceProvider);
      if (source == null) {
        return PaginatedResult.empty();
      }

      return source.getChildrenPaginated(
        itemId,
        startIndex: 0,
        limit: kMediaServerPageSize,
      );
    });

// ── PX-FE-09: Poster art mode toggle ─────────────────────────────────

/// Grid display mode for a Plex library screen.
///
/// Persisted per-library via [plexGridModeProvider].
enum PlexGridMode {
  /// 2:3 portrait poster — 2-3 columns.
  portrait,

  /// 16:9 landscape thumbnail — 1-2 columns.
  landscape,
}

/// [PX-FE-09] Per-library grid mode notifier.
///
/// Keyed by [libraryId] so each library remembers its own display mode
/// independently. State survives re-renders but not app restarts (in-memory).
class PlexGridModeNotifier extends Notifier<PlexGridMode> {
  PlexGridModeNotifier(this.libraryId);

  /// The library ID this notifier manages.
  final String libraryId;

  @override
  PlexGridMode build() => PlexGridMode.portrait;

  /// Toggles between portrait and landscape mode.
  void toggle() {
    state =
        state == PlexGridMode.portrait
            ? PlexGridMode.landscape
            : PlexGridMode.portrait;
  }
}

/// Provides the [PlexGridMode] for a given [libraryId].
///
/// Each library tracks its own display mode independently.
final plexGridModeProvider =
    NotifierProvider.family<PlexGridModeNotifier, PlexGridMode, String>(
      (arg) => PlexGridModeNotifier(arg),
    );

// ── PX-FE-12: Extras stub provider ────────────────────────────────────

/// Represents a single Plex extra (trailer, interview, etc.).
class PlexExtra {
  const PlexExtra({
    required this.title,
    required this.type,
    required this.itemId,
    this.thumbUrl,
    this.durationMs,
  });

  /// Display title.
  final String title;

  /// Extra type label (Trailer, Interview, Behind the Scenes, …).
  final String type;

  /// Plex item ID used to resolve the stream URL.
  final String itemId;

  /// Optional thumbnail URL.
  final String? thumbUrl;

  /// Duration in milliseconds.
  final int? durationMs;
}

/// [PX-FE-12] Fetches extras (trailers, interviews, behind-the-scenes) for a
/// Plex item identified by [itemId].
///
/// Extras are surfaced via the Plex `/library/metadata/{id}/extras` endpoint.
/// Until the PlexSource exposes a dedicated `getExtras()` method, this stub
/// derives available extras from [item.metadata]['extras'] if present,
/// otherwise returns an empty list.
final plexExtrasProvider = FutureProvider.autoDispose
    .family<List<PlexExtra>, MediaItem>((ref, item) async {
      final rawExtras = item.metadata['extras'];
      if (rawExtras is! List) return [];

      return rawExtras
          .cast<Map<String, dynamic>>()
          .map((e) {
            return PlexExtra(
              title: (e['title'] as String?) ?? 'Untitled',
              type: (e['subtype'] as String?) ?? 'Clip',
              itemId: (e['ratingKey'] as String?) ?? '',
              thumbUrl: e['thumb'] as String?,
              durationMs: e['duration'] as int?,
            );
          })
          .where((e) => e.itemId.isNotEmpty)
          .toList();
    });

// ── Watchlist ─────────────────────────────────────────────────────────

/// Fetches the user's Plex Watchlist.
///
/// TODO(plex-watchlist): The Plex Watchlist API requires Plex.tv cloud
/// auth (OAuth) which is not yet implemented. Once cloud auth is
/// available, call `source.getWatchlist()` here.
///
/// Returns an empty list until the API is wired up.
final plexWatchlistProvider = FutureProvider<List<MediaItem>>((ref) async {
  final source = ref.watch(plexSourceProvider);
  if (source == null) return [];

  // Stub — Plex Watchlist lives on plex.tv (cloud), not the local server.
  // Requires OAuth Plex token scoped to plex.tv, not just the local server.
  // Return empty list until cloud auth is implemented.
  return [];
});

// ── PX-FE-02: Managed users ───────────────────────────────────────────

/// Represents a Plex managed user / household member.
// PX-FE-02
class PlexManagedUser {
  const PlexManagedUser({
    required this.id,
    required this.name,
    required this.accessToken,
    this.avatarUrl,
    this.isProtected = false,
  });

  /// Unique user ID on plex.tv.
  final String id;

  /// Display name.
  final String name;

  /// User-scoped access token for switching sessions.
  final String accessToken;

  /// Optional avatar image URL.
  final String? avatarUrl;

  /// Whether the profile requires a PIN to switch.
  final bool isProtected;
}

/// [PX-FE-02] Fetches the list of Plex managed users (household members).
///
/// Calls `/accounts` on the local Plex server, which returns the server
/// owner and any managed users configured in Plex Home. Until the
/// PlexApiClient exposes a dedicated `getManagedUsers()` method this
/// provider queries the `/accounts` XML endpoint and parses the result.
///
/// Returns an empty list when:
/// - No Plex source is connected.
/// - The server does not have Plex Home enabled.
/// - The request fails (treated as non-fatal; home screen degrades
///   gracefully to the direct-to-library flow).
// PX-FE-02
final plexManagedUsersProvider = FutureProvider<List<PlexManagedUser>>((
  ref,
) async {
  final source = ref.watch(plexSourceProvider);
  if (source == null) return [];

  try {
    // Query /accounts for Plex Home users.
    final response = await source.apiClient.getRawJson(
      '${source.serverUrl}/accounts',
      token: source.accessToken,
      clientId: source.clientIdentifier,
    );

    final accounts =
        response['MediaContainer']?['Account'] as List<dynamic>? ?? [];

    return accounts.map((a) {
      final map = a as Map<String, dynamic>;
      return PlexManagedUser(
        id: (map['id'] ?? map['key'] ?? '').toString(),
        name: (map['name'] as String?) ?? 'Unknown',
        accessToken: (map['authToken'] as String?) ?? source.accessToken,
        avatarUrl: map['thumb'] as String?,
      );
    }).toList();
  } catch (_) {
    // Non-fatal — server may not have Plex Home or the endpoint may
    // differ across Plex Media Server versions.
    return [];
  }
});

/// [PX-FE-02] Holds the currently selected managed user token.
///
/// Null means no switch has occurred (uses the server-level token).
/// When non-null, all subsequent API calls should use this token.
// PX-FE-02
class PlexActiveUserNotifier extends Notifier<PlexManagedUser?> {
  @override
  PlexManagedUser? build() => null;

  /// Switches to the given managed user.
  void switchTo(PlexManagedUser user) => state = user;

  /// Reverts to the server owner account.
  void reset() => state = null;
}

// PX-FE-02
final plexActiveUserProvider =
    NotifierProvider<PlexActiveUserNotifier, PlexManagedUser?>(
      PlexActiveUserNotifier.new,
    );

// ── PX-FE-04: On Deck ─────────────────────────────────────────────────

/// [PX-FE-04] Fetches "On Deck" items — in-progress or recently started
/// media that the user has not finished.
///
/// Calls `/library/onDeck` on the local Plex server. Returns up to 20
/// items sorted by `lastViewedAt` descending (most recently watched
/// first). Each item carries a [MediaItem.playbackPositionMs] so the
/// player can resume from the correct offset.
///
/// Returns an empty list when no source is connected or the endpoint
/// is unavailable.
// PX-FE-04
final plexOnDeckProvider = FutureProvider<List<MediaItem>>((ref) async {
  final source = ref.watch(plexSourceProvider);
  if (source == null) return [];

  try {
    final response = await source.apiClient.getRawJson(
      '${source.serverUrl}/library/onDeck',
      token: source.accessToken,
      clientId: source.clientIdentifier,
      queryParams: {'X-Plex-Container-Size': '20'},
    );

    final rawItems =
        response['MediaContainer']?['Metadata'] as List<dynamic>? ?? [];

    return rawItems.map((raw) {
      final m = raw as Map<String, dynamic>;
      final thumbPath = m['thumb'] as String?;
      final artPath = m['art'] as String?;
      final thumbUrl =
          thumbPath != null
              ? '${source.serverUrl}$thumbPath'
                  '?X-Plex-Token=${source.accessToken}'
              : null;
      final backdropUrl =
          artPath != null
              ? '${source.serverUrl}$artPath'
                  '?X-Plex-Token=${source.accessToken}'
              : null;
      return MediaItem(
        id: (m['ratingKey'] ?? '').toString(),
        name: (m['title'] as String?) ?? 'Unknown',
        type: _plexTypeFromString(m['type'] as String?),
        logoUrl: thumbUrl,
        overview: m['summary'] as String?,
        durationMs: m['duration'] as int?,
        playbackPositionMs: m['viewOffset'] as int?,
        isWatched: ((m['viewCount'] as int?) ?? 0) > 0,
        metadata: {
          if (backdropUrl != null) 'backdropUrl': backdropUrl,
          if (m['year'] != null) 'year': m['year'],
        },
      );
    }).toList();
  } catch (_) {
    return [];
  }
});

// ── PX-FE-06: Featured / hero provider ──────────────────────────────

/// [PX-FE-06] Fetches featured items for the cinematic hero banner.
///
/// Calls `/hubs/home/continueWatching` first to get contextually
/// relevant items. Falls back to `/library/recentlyAdded` when the
/// hub returns fewer than 2 items. Returns up to 5 items.
// PX-FE-06
final plexFeaturedProvider = FutureProvider<List<MediaItem>>((ref) async {
  final source = ref.watch(plexSourceProvider);
  if (source == null) return [];

  Future<List<MediaItem>> fetchHub(String path) async {
    final response = await source.apiClient.getRawJson(
      '${source.serverUrl}$path',
      token: source.accessToken,
      clientId: source.clientIdentifier,
      queryParams: {'X-Plex-Container-Size': '5'},
    );
    final rawItems =
        response['MediaContainer']?['Metadata'] as List<dynamic>? ?? [];
    return rawItems.map((raw) {
      final m = raw as Map<String, dynamic>;
      final artPath = m['art'] as String?;
      final thumbPath = m['thumb'] as String?;
      final backdropUrl =
          artPath != null
              ? '${source.serverUrl}$artPath'
                  '?X-Plex-Token=${source.accessToken}'
              : null;
      final thumbUrl =
          thumbPath != null
              ? '${source.serverUrl}$thumbPath'
                  '?X-Plex-Token=${source.accessToken}'
              : null;
      return MediaItem(
        id: (m['ratingKey'] ?? '').toString(),
        name: (m['title'] as String?) ?? 'Unknown',
        type: _plexTypeFromString(m['type'] as String?),
        logoUrl: backdropUrl ?? thumbUrl,
        overview: m['summary'] as String?,
        durationMs: m['duration'] as int?,
        playbackPositionMs: m['viewOffset'] as int?,
        isWatched: ((m['viewCount'] as int?) ?? 0) > 0,
        metadata: {
          if (backdropUrl != null) 'backdropUrl': backdropUrl,
          if (thumbUrl != null) 'thumbUrl': thumbUrl,
          if (m['year'] != null) 'year': m['year'],
          if (m['rating'] != null) 'audienceRating': m['rating'],
          if (m['contentRating'] != null) 'contentRating': m['contentRating'],
        },
      );
    }).toList();
  }

  try {
    final featured = await fetchHub('/hubs/home/continueWatching');
    if (featured.length >= 2) return featured.take(5).toList();

    // Fallback: recently added.
    final recent = await fetchHub('/library/recentlyAdded');
    return recent.take(5).toList();
  } catch (_) {
    return [];
  }
});

// ── PX-FE-08: Library sort / filter state ────────────────────────────

/// Sort fields supported by the Plex `/library/sections/{id}/all` endpoint.
// PX-FE-08
enum PlexSortField {
  titleSort,
  addedAt,
  originallyAvailableAt,
  audienceRating;

  String get apiValue => switch (this) {
    PlexSortField.titleSort => 'titleSort',
    PlexSortField.addedAt => 'addedAt',
    PlexSortField.originallyAvailableAt => 'originallyAvailableAt',
    PlexSortField.audienceRating => 'audienceRating',
  };

  String get label => switch (this) {
    PlexSortField.titleSort => 'Title',
    PlexSortField.addedAt => 'Recently Added',
    PlexSortField.originallyAvailableAt => 'Release Date',
    PlexSortField.audienceRating => 'Rating',
  };
}

/// Sort direction.
// PX-FE-08
enum PlexSortDirection {
  asc,
  desc;

  String get apiSuffix => this == PlexSortDirection.asc ? ':asc' : ':desc';
}

/// Immutable filter state for a Plex library screen.
// PX-FE-08
class PlexLibraryFilterState {
  const PlexLibraryFilterState({
    this.sortField = PlexSortField.titleSort,
    this.sortDirection = PlexSortDirection.asc,
    this.genre,
    this.decade,
    this.contentRating,
    this.resolution,
    this.hdr,
  });

  final PlexSortField sortField;
  final PlexSortDirection sortDirection;

  /// Genre filter (e.g. "Action", "Drama"). Null = all genres.
  final String? genre;

  /// Decade filter (e.g. "2010s"). Null = all decades.
  final String? decade;

  /// Content rating filter (e.g. "PG-13"). Null = all ratings.
  final String? contentRating;

  /// Resolution filter (e.g. "4k", "1080"). Null = all resolutions.
  final String? resolution;

  /// HDR filter. Null = all; true = HDR only; false = SDR only.
  final bool? hdr;

  /// Whether any filter (non-sort) is active.
  bool get hasActiveFilters =>
      genre != null ||
      decade != null ||
      contentRating != null ||
      resolution != null ||
      hdr != null;

  /// Converts the state to Plex API query parameters.
  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'sort': '${sortField.apiValue}${sortDirection.apiSuffix}',
    };
    if (genre != null) params['genre'] = genre!;
    if (contentRating != null) params['contentRating'] = contentRating!;
    if (resolution != null) params['resolution'] = resolution!;
    if (hdr == true) params['hdr'] = '1';
    // Decade is expressed as a year range: 2010s → year>=2010&year<=2019.
    if (decade != null) {
      final base = int.tryParse(decade!.replaceAll(RegExp(r'[^\d]'), ''));
      if (base != null) {
        params['year>>'] = '$base';
        params['year<<'] = '${base + 9}';
      }
    }
    return params;
  }

  PlexLibraryFilterState copyWith({
    PlexSortField? sortField,
    PlexSortDirection? sortDirection,
    Object? genre = _sentinel,
    Object? decade = _sentinel,
    Object? contentRating = _sentinel,
    Object? resolution = _sentinel,
    Object? hdr = _sentinel,
  }) {
    return PlexLibraryFilterState(
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      genre: identical(genre, _sentinel) ? this.genre : genre as String?,
      decade: identical(decade, _sentinel) ? this.decade : decade as String?,
      contentRating:
          identical(contentRating, _sentinel)
              ? this.contentRating
              : contentRating as String?,
      resolution:
          identical(resolution, _sentinel)
              ? this.resolution
              : resolution as String?,
      hdr: identical(hdr, _sentinel) ? this.hdr : hdr as bool?,
    );
  }
}

// Sentinel value for copyWith nullable fields.
const Object _sentinel = Object();

/// [PX-FE-08] Per-library filter/sort notifier.
///
/// Keyed by [libraryId]. Each library tracks its own filter
/// state independently in memory.
// PX-FE-08
class PlexLibraryFilterNotifier extends Notifier<PlexLibraryFilterState> {
  PlexLibraryFilterNotifier(this.libraryId);

  final String libraryId;

  @override
  PlexLibraryFilterState build() => const PlexLibraryFilterState();

  void setSort(PlexSortField field) {
    if (state.sortField == field) {
      // Toggle direction when same field is tapped again.
      state = state.copyWith(
        sortDirection:
            state.sortDirection == PlexSortDirection.asc
                ? PlexSortDirection.desc
                : PlexSortDirection.asc,
      );
    } else {
      state = state.copyWith(
        sortField: field,
        sortDirection: PlexSortDirection.asc,
      );
    }
  }

  void setGenre(String? genre) => state = state.copyWith(genre: genre);
  void setDecade(String? decade) => state = state.copyWith(decade: decade);
  void setContentRating(String? rating) =>
      state = state.copyWith(contentRating: rating);
  void setResolution(String? res) => state = state.copyWith(resolution: res);
  void setHdr(bool? hdr) => state = state.copyWith(hdr: hdr);

  void clearFilters() =>
      state = PlexLibraryFilterState(
        sortField: state.sortField,
        sortDirection: state.sortDirection,
      );
}

// PX-FE-08
final plexLibraryFilterProvider = NotifierProvider.family<
  PlexLibraryFilterNotifier,
  PlexLibraryFilterState,
  String
>((arg) => PlexLibraryFilterNotifier(arg));

// ── Internal helpers ──────────────────────────────────────────────────

/// Maps a raw Plex type string to [MediaType].
MediaType _plexTypeFromString(String? type) {
  switch (type) {
    case 'movie':
      return MediaType.movie;
    case 'show':
      return MediaType.series;
    case 'season':
      return MediaType.season;
    case 'episode':
      return MediaType.episode;
    default:
      return MediaType.unknown;
  }
}
