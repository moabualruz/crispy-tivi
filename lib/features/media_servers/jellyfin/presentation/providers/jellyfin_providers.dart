import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_source.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/providers/media_server_providers.dart';

// Re-export the shared public-users provider so existing callers that
// import this file keep working without changes.
export 'package:crispy_tivi/features/media_servers/shared/presentation/providers/public_users_provider.dart'
    show mediaServerPublicUsersProvider;

// ── Thin wrappers delegating to the shared media-server factory ───────

/// Provider for the active Jellyfin [MediaServerSource].
final jellyfinSourceProvider = Provider<MediaServerSource?>((ref) {
  final source = ref.watch(
    mediaServerSourceProvider(PlaylistSourceType.jellyfin),
  );
  return source is MediaServerSource ? source : null;
});

// ── Library State ─────────────────────────────────────────────────────

/// Fetches root Jellyfin libraries (user views).
final jellyfinLibrariesProvider = FutureProvider<List<MediaItem>>((ref) async {
  return ref.watch(
    mediaServerLibrariesProvider(PlaylistSourceType.jellyfin).future,
  );
});

/// Fetches Jellyfin items within a folder.
final jellyfinItemsProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  parentId,
) async {
  return ref.watch(
    mediaServerItemsProvider(
      MediaServerLibraryQuery(
        type: PlaylistSourceType.jellyfin,
        parentId: parentId,
      ),
    ).future,
  );
});

/// Resolves the playback URL for a Jellyfin item.
final jellyfinStreamUrlProvider = FutureProvider.family<String, String>((
  ref,
  itemId,
) async {
  return ref.read(
    mediaServerStreamUrlProvider(
      MediaServerStreamQuery(type: PlaylistSourceType.jellyfin, itemId: itemId),
    ).future,
  );
});

// ── Paginated Library State ──────────────────────────────────────────

/// Paginated Jellyfin library items for a parent folder.
final jellyfinPaginatedItemsProvider = FutureProvider.autoDispose
    .family<PaginatedResult<MediaItem>, String>((ref, parentId) async {
      return ref.watch(
        mediaServerPaginatedItemsProvider(
          MediaServerLibraryQuery(
            type: PlaylistSourceType.jellyfin,
            parentId: parentId,
          ),
        ).future,
      );
    });

// ── Personalized Sections ─────────────────────────────────────────────

/// Fetches the logged-in user's favorite items (FE-JF-07).
///
/// Returns movies and series marked as favorite on the Jellyfin server.
/// Silently returns an empty list on failure so the section is hidden.
final jellyfinFavoritesProvider = FutureProvider<List<MediaItem>>((ref) async {
  final source = ref.watch(
    mediaServerSourceProvider(PlaylistSourceType.jellyfin),
  );
  if (source is! MediaServerSource) return [];

  try {
    return source.getFavorites();
  } catch (_) {
    return [];
  }
});

/// Fetches recently added items (global, across all libraries).
///
/// Used by the "Recently Added" section on the Jellyfin home screen.
final jellyfinRecentlyAddedProvider = FutureProvider<List<MediaItem>>((
  ref,
) async {
  final source = ref.watch(
    mediaServerSourceProvider(PlaylistSourceType.jellyfin),
  );
  if (source is! MediaServerSource) return [];

  try {
    return source.getRecentlyAdded();
  } catch (_) {
    return [];
  }
});

// FE-JF-04: Continue Watching provider.
/// Fetches items with saved resume positions ("Continue Watching").
///
/// Uses `/Users/{userId}/Items/Resume` to return in-progress movies
/// and episodes. Silently returns empty on failure so the row is hidden.
final jellyfinResumeItemsProvider = FutureProvider<List<MediaItem>>((
  ref,
) async {
  final source = ref.watch(jellyfinSourceProvider);
  if (source == null) return [];

  try {
    return source.getResumeItems();
  } catch (_) {
    return [];
  }
});

// FE-JF-05: Next Up provider.
/// Fetches the next unwatched episode per in-progress series.
///
/// Uses `/Shows/NextUp`. Silently returns empty on failure.
final jellyfinNextUpProvider = FutureProvider<List<MediaItem>>((ref) async {
  final source = ref.watch(jellyfinSourceProvider);
  if (source == null) return [];

  try {
    return source.getNextUp();
  } catch (_) {
    return [];
  }
});

// FE-JF-06: Recently Added per library provider (family by library ID).
/// Fetches recently added items scoped to a specific Jellyfin library.
///
/// Family parameter is the library/parent folder ID.
/// Uses `/Users/{userId}/Items/Latest` per library.
/// Silently returns empty on failure.
final jellyfinRecentlyAddedByLibraryProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, libraryId) async {
      final source = ref.watch(jellyfinSourceProvider);
      if (source == null) return [];

      try {
        return source.getLatestByLibrary(libraryId);
      } catch (_) {
        return [];
      }
    });

// ── FE-JF-08: Sort / Filter State ─────────────────────────────────────

/// Sort field options for Jellyfin library filter toolbar.
enum JellyfinSortField {
  name('SortName', 'Name'),
  dateAdded('DateCreated', 'Date Added'),
  year('ProductionYear', 'Year'),
  rating('CommunityRating', 'Rating'),
  runtime('Runtime', 'Runtime');

  const JellyfinSortField(this.apiValue, this.label);

  /// Value sent to the server `SortBy` query parameter.
  final String apiValue;

  /// Human-readable label for the UI.
  final String label;
}

/// State for the Jellyfin library sort/filter toolbar (FE-JF-08).
class JellyfinLibraryFilter {
  const JellyfinLibraryFilter({
    this.sortField = JellyfinSortField.name,
    this.sortDescending = false,
    this.selectedGenres = const {},
    this.watchedOnly = false,
    this.unwatchedOnly = false,
    this.hdrOnly = false,
  });

  final JellyfinSortField sortField;
  final bool sortDescending;

  /// Set of genre names to filter by (empty = no genre filter).
  final Set<String> selectedGenres;

  final bool watchedOnly;
  final bool unwatchedOnly;
  final bool hdrOnly;

  String get sortOrder => sortDescending ? 'Descending' : 'Ascending';

  JellyfinLibraryFilter copyWith({
    JellyfinSortField? sortField,
    bool? sortDescending,
    Set<String>? selectedGenres,
    bool? watchedOnly,
    bool? unwatchedOnly,
    bool? hdrOnly,
  }) {
    return JellyfinLibraryFilter(
      sortField: sortField ?? this.sortField,
      sortDescending: sortDescending ?? this.sortDescending,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      watchedOnly: watchedOnly ?? this.watchedOnly,
      unwatchedOnly: unwatchedOnly ?? this.unwatchedOnly,
      hdrOnly: hdrOnly ?? this.hdrOnly,
    );
  }
}

/// Notifier for [JellyfinLibraryFilter] — local state, not persisted.
///
/// Each [JellyfinLibraryScreen] instance gets its own scoped notifier
/// via [jellyfinLibraryFilterProvider].
class JellyfinLibraryFilterNotifier extends Notifier<JellyfinLibraryFilter> {
  @override
  JellyfinLibraryFilter build() => const JellyfinLibraryFilter();

  void setSortField(JellyfinSortField field) {
    if (state.sortField == field) {
      // Toggle direction when re-selecting the same field.
      state = state.copyWith(sortDescending: !state.sortDescending);
    } else {
      state = state.copyWith(sortField: field, sortDescending: false);
    }
  }

  void toggleGenre(String genre) {
    final genres = Set<String>.from(state.selectedGenres);
    if (genres.contains(genre)) {
      genres.remove(genre);
    } else {
      genres.add(genre);
    }
    state = state.copyWith(selectedGenres: genres);
  }

  void setWatchedOnly(bool value) {
    state = state.copyWith(
      watchedOnly: value,
      unwatchedOnly: value ? false : state.unwatchedOnly,
    );
  }

  void setUnwatchedOnly(bool value) {
    state = state.copyWith(
      unwatchedOnly: value,
      watchedOnly: value ? false : state.watchedOnly,
    );
  }

  void setHdrOnly(bool value) {
    state = state.copyWith(hdrOnly: value);
  }

  void reset() {
    state = const JellyfinLibraryFilter();
  }
}

/// Provider for the per-screen Jellyfin library filter/sort state.
///
/// Use with `.overrideWithProvider` or watch directly when a single
/// filter instance is needed.
final jellyfinLibraryFilterProvider =
    NotifierProvider<JellyfinLibraryFilterNotifier, JellyfinLibraryFilter>(
      JellyfinLibraryFilterNotifier.new,
    );

// FE-JF-06: Paginated filtered library items.
/// Fetches a filtered, sorted page of library items for [JellyfinLibraryScreen].
///
/// Family parameter: [JellyfinFilteredLibraryQuery] combining parentId + filter.
final jellyfinFilteredLibraryProvider = FutureProvider.autoDispose
    .family<PaginatedResult<MediaItem>, JellyfinFilteredLibraryQuery>((
      ref,
      query,
    ) async {
      final source = ref.watch(jellyfinSourceProvider);
      if (source == null) return PaginatedResult.empty();

      final filter = query.filter;

      return source.getLibraryFiltered(
        query.parentId,
        startIndex: query.startIndex,
        sortBy: filter.sortField.apiValue,
        sortOrder: filter.sortOrder,
        isHdr: filter.hdrOnly ? true : null,
        genres:
            filter.selectedGenres.isNotEmpty
                ? filter.selectedGenres.join(',')
                : null,
      );
    });

/// Query key for [jellyfinFilteredLibraryProvider].
class JellyfinFilteredLibraryQuery {
  const JellyfinFilteredLibraryQuery({
    required this.parentId,
    required this.filter,
    this.startIndex = 0,
  });

  final String parentId;
  final JellyfinLibraryFilter filter;
  final int startIndex;

  @override
  bool operator ==(Object other) =>
      other is JellyfinFilteredLibraryQuery &&
      parentId == other.parentId &&
      startIndex == other.startIndex &&
      filter.sortField == other.filter.sortField &&
      filter.sortDescending == other.filter.sortDescending &&
      filter.selectedGenres == other.filter.selectedGenres &&
      filter.watchedOnly == other.filter.watchedOnly &&
      filter.unwatchedOnly == other.filter.unwatchedOnly &&
      filter.hdrOnly == other.filter.hdrOnly;

  @override
  int get hashCode => Object.hash(
    parentId,
    startIndex,
    filter.sortField,
    filter.sortDescending,
    filter.selectedGenres,
    filter.watchedOnly,
    filter.unwatchedOnly,
    filter.hdrOnly,
  );
}

// ── JF-FE-12: Series Navigation ──────────────────────────────────────

/// Fetches seasons for a Jellyfin series item by [seriesId].
///
/// Calls `/Users/{userId}/Items?ParentId={seriesId}` and returns the
/// season list. Returns an empty list on failure so the tab bar is hidden.
final jellyfinSeasonsProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, seriesId) async {
      // JF-FE-12
      final source = ref.watch(jellyfinSourceProvider);
      if (source == null) return [];
      try {
        return source.getLibrary(seriesId);
      } catch (_) {
        return [];
      }
    });

/// Fetches episodes for a Jellyfin season.
///
/// Family parameter: `(seriesId, seasonId)` pair — seriesId is kept for
/// cache-key disambiguation when a user navigates multiple seasons.
/// Returns an empty list on failure.
final jellyfinEpisodesProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, (String, String)>((ref, args) async {
      // JF-FE-12
      final (_, seasonId) = args;
      final source = ref.watch(jellyfinSourceProvider);
      if (source == null) return [];
      try {
        return source.getLibrary(seasonId);
      } catch (_) {
        return [];
      }
    });
