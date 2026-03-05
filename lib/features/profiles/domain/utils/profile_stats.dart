import '../../../player/domain/entities/watch_history_entry.dart';
import 'watch_streak.dart';

/// Aggregated viewing statistics for a single profile.
class ProfileViewingStats {
  const ProfileViewingStats({
    required this.totalHoursWatched,
    required this.topGenres,
    required this.topChannels,
    required this.watchStreakDays,
  });

  /// Total hours of content watched (sum of positionMs / 3_600_000).
  final double totalHoursWatched;

  /// Top 3 genres by watch count.
  ///
  /// Genres are extracted from the [WatchHistoryEntry.name] as a best-effort
  /// heuristic — a proper genre field would require a richer data model.
  /// For now genres are derived from the [mediaType] category.
  final List<String> topGenres;

  /// Top 3 channel/show names by watch count.
  final List<String> topChannels;

  /// Current consecutive watch streak in days.
  ///
  /// Counts how many consecutive calendar days (ending today or yesterday)
  /// have at least one watched entry.
  final int watchStreakDays;

  /// Computes stats from a list of history [entries] for one profile.
  factory ProfileViewingStats.compute(List<WatchHistoryEntry> entries) {
    if (entries.isEmpty) {
      return const ProfileViewingStats(
        totalHoursWatched: 0,
        topGenres: [],
        topChannels: [],
        watchStreakDays: 0,
      );
    }

    // Total watch time from positionMs (ms → hours).
    final totalMs = entries.fold<int>(0, (sum, e) => sum + e.positionMs);
    final totalHours = totalMs / 3600000.0;

    // Top channels — by frequency of name occurrence.
    final channelCounts = <String, int>{};
    for (final e in entries) {
      final key = e.seriesId != null ? (e.name.split(' - ').first) : e.name;
      channelCounts[key] = (channelCounts[key] ?? 0) + 1;
    }
    final topChannels =
        (channelCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .map((e) => e.key)
            .toList();

    // Top genres — derived from mediaType as a broad category label.
    final genreCounts = <String, int>{};
    for (final e in entries) {
      final genre = mediaTypeToGenreLabel(e.mediaType);
      genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
    }
    final topGenres =
        (genreCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .map((e) => e.key)
            .toList();

    // Watch streak — consecutive calendar days with any entry.
    final streak = computeWatchStreak(entries);

    return ProfileViewingStats(
      totalHoursWatched: totalHours,
      topGenres: topGenres,
      topChannels: topChannels,
      watchStreakDays: streak,
    );
  }

  /// Maps a [WatchHistoryEntry.mediaType] string to a user-friendly genre label.
  static String mediaTypeToGenreLabel(String mediaType) {
    switch (mediaType) {
      case 'movie':
        return 'Movies';
      case 'episode':
        return 'Series';
      case 'channel':
        return 'Live TV';
      default:
        return 'Other';
    }
  }
}
