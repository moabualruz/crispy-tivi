import '../../../player/domain/entities/watch_history_entry.dart';

/// Status filter for the Continue Watching tab (FE-FAV-03).
enum CwFilter { all, watching, completed }

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
