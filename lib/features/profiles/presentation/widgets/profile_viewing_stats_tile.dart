import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/domain/entities/watch_history_entry.dart';

/// Riverpod provider that computes [ProfileViewingStats] for a given profile.
///
/// Reads all watch history and filters to the given [profileId].
final profileViewingStatsProvider =
    FutureProvider.family<ProfileViewingStats, String>((ref, profileId) async {
      final service = ref.watch(watchHistoryServiceProvider);
      final all = await service.getAll();
      final entries = all.where((e) => e.profileId == profileId).toList();
      return ProfileViewingStats.compute(entries);
    });

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
      final genre = _mediaTypeToGenreLabel(e.mediaType);
      genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
    }
    final topGenres =
        (genreCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .map((e) => e.key)
            .toList();

    // Watch streak — consecutive calendar days with any entry.
    final streak = _computeStreak(entries);

    return ProfileViewingStats(
      totalHoursWatched: totalHours,
      topGenres: topGenres,
      topChannels: topChannels,
      watchStreakDays: streak,
    );
  }

  /// Maps a [WatchHistoryEntry.mediaType] string to a user-friendly genre label.
  static String _mediaTypeToGenreLabel(String mediaType) {
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

  /// Computes the current watch streak (consecutive days ending today or
  /// yesterday with at least one entry).
  static int _computeStreak(List<WatchHistoryEntry> entries) {
    if (entries.isEmpty) return 0;

    // Collect distinct calendar days (local time).
    final days = <DateTime>{};
    for (final e in entries) {
      final d = e.lastWatched;
      days.add(DateTime(d.year, d.month, d.day));
    }

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

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
}

/// A card tile showing viewing statistics for a profile (FE-PM-09).
///
/// Displays:
/// - Total hours watched
/// - Top 3 genres
/// - Top 3 channels / shows
/// - Watch streak (consecutive days)
class ProfileViewingStatsTile extends ConsumerWidget {
  const ProfileViewingStatsTile({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(profileViewingStatsProvider(profileId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.bar_chart, size: 18, color: colorScheme.primary),
                const SizedBox(width: CrispySpacing.sm),
                Text(
                  'Viewing Stats',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispySpacing.md),

            statsAsync.when(
              loading:
                  () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: CrispySpacing.md),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              error:
                  (err, st) => Text(
                    'Could not load stats.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              data: (stats) => _StatsContent(stats: stats),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the stat rows when data is available.
class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.stats});

  final ProfileViewingStats stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hoursLabel =
        stats.totalHoursWatched < 1
            ? '${(stats.totalHoursWatched * 60).round()} min'
            : '${stats.totalHoursWatched.toStringAsFixed(1)} h';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row: total hours + streak
        Row(
          children: [
            Expanded(
              child: _StatBox(
                icon: Icons.play_circle_outline,
                label: 'Total Watched',
                value: hoursLabel,
              ),
            ),
            const SizedBox(width: CrispySpacing.sm),
            Expanded(
              child: _StatBox(
                icon: Icons.local_fire_department,
                label: 'Streak',
                value:
                    stats.watchStreakDays == 0
                        ? 'None'
                        : '${stats.watchStreakDays} day${stats.watchStreakDays == 1 ? '' : 's'}',
              ),
            ),
          ],
        ),
        const SizedBox(height: CrispySpacing.md),

        if (stats.topGenres.isNotEmpty) ...[
          Text(
            'Top Categories',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: CrispySpacing.xs),
          Wrap(
            spacing: CrispySpacing.xs,
            runSpacing: CrispySpacing.xs,
            children: stats.topGenres.map((g) => _GenreChip(label: g)).toList(),
          ),
          const SizedBox(height: CrispySpacing.md),
        ],

        if (stats.topChannels.isNotEmpty) ...[
          Text(
            'Most Watched',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: CrispySpacing.xs),
          ...stats.topChannels.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: CrispySpacing.xs),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(CrispyRadius.tv),
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: CrispySpacing.sm),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (stats.topGenres.isEmpty && stats.topChannels.isEmpty)
          Text(
            'No watch history yet.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// A small summary box with icon, label, and value.
class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(CrispySpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(height: CrispySpacing.xs),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip displaying a genre label.
class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
