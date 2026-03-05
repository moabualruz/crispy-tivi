import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Shared library filter base types ──────────────────────────────────
//
// `MediaLibraryFilter` and `MediaLibraryFilterNotifier` capture the
// fields and mutations that are common to every media-server library
// filter (Emby, Jellyfin, Plex).  Server-specific fields and methods
// live in the concrete subclasses defined in each server's provider
// file.

/// Immutable base class for media-server library filter state.
///
/// Common fields:
/// - [hdrOnly]       — show only HDR content.
/// - [selectedGenres] — set of genre names to include (empty = all).
///
/// Concrete subclasses add server-specific fields (e.g. Emby
/// `selectedYears`, Jellyfin `watchedOnly`, Plex `decade`).
abstract class MediaLibraryFilter {
  const MediaLibraryFilter({
    this.hdrOnly = false,
    this.selectedGenres = const {},
  });

  /// Show HDR content only when `true`.
  final bool hdrOnly;

  /// Genre names to filter by.  Empty set means no genre filter.
  final Set<String> selectedGenres;

  /// Whether any non-default filter is currently active.
  bool get hasActiveFilters;

  /// Returns a copy of this filter with the given fields replaced.
  ///
  /// Subclasses must override this to preserve their own fields.
  MediaLibraryFilter copyWithBase({bool? hdrOnly, Set<String>? selectedGenres});
}

/// Abstract Riverpod notifier that manages a [MediaLibraryFilter]
/// subclass `F`.
///
/// Provides the mutations that are identical across all three servers:
/// - [toggleGenre]  — add/remove a genre from [selectedGenres].
/// - [toggleHdr]    — flip the [hdrOnly] flag.
///
/// Subclasses must implement:
/// - `build()` — return the server-specific default state.
/// - [reset]   — restore the default state.
/// - [updateState] — apply a new `F` instance to [state].
///
/// The [updateState] indirection is needed because Dart generics do not
/// allow calling `state = newValue` from an abstract superclass when the
/// type parameter `F` is covariant.  Subclasses implement it as a
/// one-liner: `void updateState(F s) => state = s;`.
abstract class MediaLibraryFilterNotifier<F extends MediaLibraryFilter>
    extends Notifier<F> {
  // ── Subclass contract ───────────────────────────────────────────────

  /// Restore the default (cleared) filter state.
  void reset();

  /// Apply [newState] by assigning it to [state].
  ///
  /// Implement as `void updateState(F s) => state = s;` in every
  /// concrete subclass.
  void updateState(F newState);

  // ── Shared mutations ────────────────────────────────────────────────

  /// Adds [genre] to [selectedGenres] if absent; removes it if present.
  void toggleGenre(String genre) {
    final genres = Set<String>.from(state.selectedGenres);
    if (genres.contains(genre)) {
      genres.remove(genre);
    } else {
      genres.add(genre);
    }
    updateState(state.copyWithBase(selectedGenres: genres) as F);
  }

  /// Flips the [hdrOnly] flag.
  void toggleHdr() {
    updateState(state.copyWithBase(hdrOnly: !state.hdrOnly) as F);
  }
}
