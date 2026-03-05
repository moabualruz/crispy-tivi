import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_source.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/providers/media_server_providers.dart';

// Re-export the shared public-users provider under the legacy Emby alias so
// existing callers that import this file keep working without changes.
export 'package:crispy_tivi/features/media_servers/shared/presentation/providers/public_users_provider.dart'
    show mediaServerPublicUsersProvider;

// ── Thin wrappers delegating to the shared media-server factory ───────

/// Provider for the active Emby [MediaServerSource].
final embySourceProvider = Provider<MediaServerSource?>((ref) {
  final source = ref.watch(mediaServerSourceProvider(PlaylistSourceType.emby));
  return source is MediaServerSource ? source : null;
});

// ── Library State ─────────────────────────────────────────────────────

/// Fetches root Emby libraries (user views).
final embyLibrariesProvider = FutureProvider<List<MediaItem>>((ref) async {
  return ref.watch(
    mediaServerLibrariesProvider(PlaylistSourceType.emby).future,
  );
});

/// Fetches Emby items within a folder.
final embyItemsProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  parentId,
) async {
  return ref.watch(
    mediaServerItemsProvider(
      MediaServerLibraryQuery(
        type: PlaylistSourceType.emby,
        parentId: parentId,
      ),
    ).future,
  );
});

/// Resolves the playback URL for an Emby item.
final embyStreamUrlProvider = FutureProvider.family<String, String>((
  ref,
  itemId,
) async {
  return ref.read(
    mediaServerStreamUrlProvider(
      MediaServerStreamQuery(type: PlaylistSourceType.emby, itemId: itemId),
    ).future,
  );
});

// ── Paginated Library State ──────────────────────────────────────────

/// Paginated Emby library items for a parent folder.
final embyPaginatedItemsProvider = FutureProvider.autoDispose
    .family<PaginatedResult<MediaItem>, String>((ref, parentId) async {
      return ref.watch(
        mediaServerPaginatedItemsProvider(
          MediaServerLibraryQuery(
            type: PlaylistSourceType.emby,
            parentId: parentId,
          ),
        ).future,
      );
    });

// ── FE-EB-04: Continue Watching ───────────────────────────────────────

/// Fetches in-progress items (movies/episodes) for the resume row.
///
/// Calls `/Users/{userId}/Items/Resume` — items with saved playback
/// position. Returns an empty list on failure so the row is hidden.
final embyResumeItemsProvider = FutureProvider<List<MediaItem>>((ref) async {
  // FE-EB-04
  final source = ref.watch(embySourceProvider);
  if (source == null) return [];
  try {
    return source.getResumeItems();
  } catch (_) {
    return [];
  }
});

// ── FE-EB-05: Next Up ────────────────────────────────────────────────

/// Fetches the next unwatched episode per in-progress series.
///
/// Calls `/Shows/NextUp`. Returns an empty list on failure.
final embyNextUpProvider = FutureProvider<List<MediaItem>>((ref) async {
  // FE-EB-05
  final source = ref.watch(embySourceProvider);
  if (source == null) return [];
  try {
    return source.getNextUp();
  } catch (_) {
    return [];
  }
});

// ── FE-EB-06: Recently Added per Library ─────────────────────────────

/// Fetches recently added items scoped to a specific library [parentId].
///
/// Calls `/Users/{userId}/Items/Latest?ParentId={parentId}`. Limited to
/// 16 items per library. Returns empty on failure.
final embyRecentlyAddedProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, parentId) async {
      // FE-EB-06
      final source = ref.watch(embySourceProvider);
      if (source == null) return [];
      try {
        return source.getLatestByLibrary(parentId);
      } catch (_) {
        return [];
      }
    });

// ── FE-EB-10: Collections / Box Sets ─────────────────────────────────

/// Fetches BoxSet (collection) items from the Emby server.
///
/// Collections are curated groups of movies/shows (e.g. "MCU"). Returns
/// an empty list on failure so the section is hidden gracefully.
final embyCollectionsProvider = FutureProvider<List<MediaItem>>((ref) async {
  // FE-EB-10
  final source = ref.watch(embySourceProvider);
  if (source == null) return [];
  try {
    return source.getCollections();
  } catch (_) {
    return [];
  }
});

// ── FE-EB-08: Library Filter State ───────────────────────────────────

/// Sort option for the Emby library filter toolbar.
enum EmbyLibrarySortBy {
  name('SortName', 'Name'),
  dateCreated('DateCreated', 'Date Added'),
  premiereDate('PremiereDate', 'Release Date'),
  communityRating('CommunityRating', 'Rating');

  const EmbyLibrarySortBy(this.apiValue, this.label);

  /// Value sent in the `SortBy` query parameter.
  final String apiValue;

  /// Human-readable label shown in the filter chip.
  final String label;
}

/// Immutable filter state for [EmbyLibraryFilterNotifier].
class EmbyLibraryFilter {
  const EmbyLibraryFilter({
    this.sortBy = EmbyLibrarySortBy.name,
    this.ascending = true,
    this.selectedGenres = const [],
    this.selectedYears = const [],
    this.hdOnly = false,
    this.hdrOnly = false,
  });

  final EmbyLibrarySortBy sortBy;
  final bool ascending;
  final List<String> selectedGenres;
  final List<String> selectedYears;
  final bool hdOnly;
  final bool hdrOnly;

  /// Converts genre list to comma-separated API param (null if empty).
  String? get genresParam =>
      selectedGenres.isEmpty ? null : selectedGenres.join(',');

  /// Converts year list to comma-separated API param (null if empty).
  String? get yearsParam =>
      selectedYears.isEmpty ? null : selectedYears.join(',');

  EmbyLibraryFilter copyWith({
    EmbyLibrarySortBy? sortBy,
    bool? ascending,
    List<String>? selectedGenres,
    List<String>? selectedYears,
    bool? hdOnly,
    bool? hdrOnly,
  }) {
    return EmbyLibraryFilter(
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      selectedYears: selectedYears ?? this.selectedYears,
      hdOnly: hdOnly ?? this.hdOnly,
      hdrOnly: hdrOnly ?? this.hdrOnly,
    );
  }
}

/// Notifier that holds the current filter/sort state for a library screen.
///
/// Scoped per-library via the [parentId] family parameter so each
/// [EmbyLibraryScreen] instance keeps its own filter state.
class EmbyLibraryFilterNotifier extends Notifier<EmbyLibraryFilter> {
  @override
  EmbyLibraryFilter build() => const EmbyLibraryFilter();

  /// Updates the sort field; resets to ascending when the field changes.
  void setSortBy(EmbyLibrarySortBy sortBy) {
    // FE-EB-08
    state = state.copyWith(sortBy: sortBy, ascending: true);
  }

  /// Toggles sort direction.
  void toggleSortOrder() {
    // FE-EB-08
    state = state.copyWith(ascending: !state.ascending);
  }

  /// Toggles a genre in the selected set.
  void toggleGenre(String genre) {
    // FE-EB-08
    final current = List<String>.from(state.selectedGenres);
    current.contains(genre) ? current.remove(genre) : current.add(genre);
    state = state.copyWith(selectedGenres: current);
  }

  /// Toggles a year in the selected set.
  void toggleYear(String year) {
    // FE-EB-08
    final current = List<String>.from(state.selectedYears);
    current.contains(year) ? current.remove(year) : current.add(year);
    state = state.copyWith(selectedYears: current);
  }

  /// Toggles the HD-only filter.
  void toggleHd() {
    // FE-EB-08
    state = state.copyWith(hdOnly: !state.hdOnly);
  }

  /// Toggles the HDR-only filter.
  void toggleHdr() {
    // FE-EB-08
    state = state.copyWith(hdrOnly: !state.hdrOnly);
  }

  /// Clears all active filters.
  void clearAll() {
    // FE-EB-08
    state = const EmbyLibraryFilter();
  }
}

/// Provider family for [EmbyLibraryFilterNotifier], keyed by library ID.
final embyLibraryFilterProvider =
    NotifierProvider.autoDispose<EmbyLibraryFilterNotifier, EmbyLibraryFilter>(
      EmbyLibraryFilterNotifier.new,
    );

// ── EB-FE-11: Series Navigation ──────────────────────────────────────

/// Fetches seasons for an Emby series item by [seriesId].
///
/// Calls `/Users/{userId}/Items?ParentId={seriesId}&IncludeItemTypes=Season`
/// and returns seasons sorted by index. Returns an empty list on failure.
final embySeasonsProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, seriesId) async {
      // EB-FE-11
      final source = ref.watch(embySourceProvider);
      if (source == null) return [];
      try {
        return source.getLibrary(seriesId);
      } catch (_) {
        return [];
      }
    });

/// Fetches episodes for an Emby season.
///
/// Calls `/Users/{userId}/Items?ParentId={seasonId}&IncludeItemTypes=Episode`
/// and returns episodes sorted by index. Returns an empty list on failure.
///
/// Family parameter: `(seriesId, seasonId)` pair — seriesId is kept for
/// cache-key disambiguation when a user navigates multiple seasons.
final embyEpisodesProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, (String, String)>((ref, args) async {
      // EB-FE-11
      final (_, seasonId) = args;
      final source = ref.watch(embySourceProvider);
      if (source == null) return [];
      try {
        return source.getLibrary(seasonId);
      } catch (_) {
        return [];
      }
    });
