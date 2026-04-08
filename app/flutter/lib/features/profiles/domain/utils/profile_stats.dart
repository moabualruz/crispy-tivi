/// Aggregated viewing statistics for a single profile.
///
/// Constructed from the JSON returned by
/// `backend.computeProfileStats(historyJson, nowMs)`.
class ProfileViewingStats {
  const ProfileViewingStats({
    required this.totalHoursWatched,
    required this.topGenres,
    required this.topChannels,
    required this.watchStreakDays,
  });

  /// Parses the JSON map returned by the Rust backend's
  /// `computeProfileStats` function.
  factory ProfileViewingStats.fromJson(Map<String, dynamic> json) {
    return ProfileViewingStats(
      totalHoursWatched: (json['total_hours_watched'] as num?)?.toDouble() ?? 0,
      topGenres:
          (json['top_genres'] as List?)?.cast<String>() ?? const <String>[],
      topChannels:
          (json['top_channels'] as List?)?.cast<String>() ?? const <String>[],
      watchStreakDays: (json['watch_streak_days'] as num?)?.toInt() ?? 0,
    );
  }

  /// Total hours of content watched (sum of positionMs / 3_600_000).
  final double totalHoursWatched;

  /// Top 3 genres by watch count.
  ///
  /// Genres are derived from the media type category by the Rust backend.
  final List<String> topGenres;

  /// Top 3 channel/show names by watch count.
  final List<String> topChannels;

  /// Current consecutive watch streak in days.
  ///
  /// Counts how many consecutive calendar days (ending today or yesterday)
  /// have at least one watched entry.
  final int watchStreakDays;
}
