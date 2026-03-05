import '../../../player/domain/entities/watch_history_entry.dart';

/// Status filter for the Continue Watching tab (FE-FAV-03).
enum CwFilter { all, watching, completed }

/// Merges two [WatchHistoryEntry] lists, optionally deduplicates by
/// [WatchHistoryEntry.id], and sorts by [WatchHistoryEntry.lastWatched]
/// descending (most recently watched first).
///
/// When [deduplicate] is `true` (the default) the first occurrence of
/// each id wins and later duplicates are dropped.  Pass `false` when the
/// caller already guarantees unique ids and only needs the sort.
///
/// Pure function — no Flutter or framework imports.
List<WatchHistoryEntry> mergeDedupSort(
  List<WatchHistoryEntry> a,
  List<WatchHistoryEntry> b, {
  bool deduplicate = true,
}) {
  final combined = [...a, ...b];
  final result =
      deduplicate
          ? () {
            final seen = <String>{};
            return combined.where((e) => seen.add(e.id)).toList();
          }()
          : combined;
  return result..sort((x, y) => y.lastWatched.compareTo(x.lastWatched));
}

/// Human-readable label for each [CwFilter] value.
extension CwFilterLabel on CwFilter {
  /// Returns the display label for this filter.
  String get label {
    switch (this) {
      case CwFilter.all:
        return 'All';
      case CwFilter.watching:
        return 'Watching';
      case CwFilter.completed:
        return 'Completed';
    }
  }
}

/// Filters [entries] by [filter] status.
///
/// - [CwFilter.all] — returns all entries unchanged.
/// - [CwFilter.watching] — entries with progress > 0 and not
///   nearly complete.
/// - [CwFilter.completed] — entries that are nearly complete.
///
/// Pure function — no Flutter or framework imports.
List<WatchHistoryEntry> filterByCwStatus(
  List<WatchHistoryEntry> entries,
  CwFilter filter,
) {
  return entries.where((e) {
    switch (filter) {
      case CwFilter.all:
        return true;
      case CwFilter.watching:
        return e.progress > 0 && !e.isNearlyComplete;
      case CwFilter.completed:
        return e.isNearlyComplete;
    }
  }).toList();
}
