import '../../../player/domain/entities/watch_history_entry.dart';

/// Computes the current watch streak (consecutive calendar days
/// ending today or yesterday that each have at least one entry).
///
/// [now] is injectable for testing; defaults to [DateTime.now()].
///
/// Returns 0 when [entries] is empty or the streak is broken.
int computeWatchStreak(List<WatchHistoryEntry> entries, {DateTime? now}) {
  if (entries.isEmpty) return 0;

  // Collect distinct calendar days (local time).
  final days = <DateTime>{};
  for (final e in entries) {
    final d = e.lastWatched;
    days.add(DateTime(d.year, d.month, d.day));
  }

  final effectiveNow = now ?? DateTime.now();
  final todayNorm = DateTime(
    effectiveNow.year,
    effectiveNow.month,
    effectiveNow.day,
  );

  // Walk backwards from today; allow starting from yesterday too.
  var current =
      days.contains(todayNorm)
          ? todayNorm
          : todayNorm.subtract(const Duration(days: 1));

  if (!days.contains(current)) return 0;

  var streak = 0;
  while (days.contains(current)) {
    streak++;
    current = current.subtract(const Duration(days: 1));
  }
  return streak;
}
