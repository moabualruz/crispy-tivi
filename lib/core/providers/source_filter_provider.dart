import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profiles/data/source_access_service.dart';

/// Manages the user's active source filter selection.
///
/// Empty set = all sources (default, no filtering).
/// Non-empty = only show content from these source IDs.
/// Session-scoped — resets on app restart.
class SourceFilterNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  /// Toggles a source in/out of the active filter.
  void toggle(String sourceId) {
    if (state.contains(sourceId)) {
      state = {...state}..remove(sourceId);
    } else {
      state = {...state, sourceId};
    }
  }

  /// Clears the filter (show all sources).
  void selectAll() => state = {};

  /// Selects exactly one source.
  void selectOnly(String sourceId) => state = {sourceId};
}

/// Provider for source filter state.
final sourceFilterProvider =
    NotifierProvider<SourceFilterNotifier, Set<String>>(
      SourceFilterNotifier.new,
    );

/// Computes the effective source IDs to query, combining:
/// - User's explicit source filter ([sourceFilterProvider])
/// - Profile's accessible sources ([accessibleSourcesProvider])
///
/// Returns empty list = load all content (no filtering).
/// Returns non-empty list = filter content to these source IDs only.
final effectiveSourceIdsProvider = Provider<List<String>>((ref) {
  final filter = ref.watch(sourceFilterProvider);
  final accessible = ref.watch(accessibleSourcesProvider).value;

  // Admin with no filter → all content
  if (filter.isEmpty && accessible == null) return [];

  // Admin with filter → use filter directly
  if (accessible == null) return filter.toList();

  // Restricted profile with no filter → use profile restrictions
  if (filter.isEmpty) return accessible;

  // Restricted profile with filter → intersect
  final accessibleSet = accessible.toSet();
  return filter.where(accessibleSet.contains).toList();
});
