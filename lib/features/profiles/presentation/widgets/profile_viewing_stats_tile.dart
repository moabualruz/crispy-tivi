import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../player/data/watch_history_service.dart';
import '../../domain/utils/profile_stats.dart';

/// Riverpod provider that computes [ProfileViewingStats] for a given profile.
///
/// Reads all watch history, filters to the given [profileId], and delegates
/// computation to the Rust backend via [CrispyBackend.computeProfileStats].
final profileViewingStatsProvider =
    FutureProvider.family<ProfileViewingStats, String>((ref, profileId) async {
      final service = ref.watch(watchHistoryServiceProvider);
      final backend = ref.read(crispyBackendProvider);
      final all = await service.getAll();
      final entries = all.where((e) => e.profileId == profileId).toList();
      final historyJson = jsonEncode(
        entries.map(watchHistoryEntryToMap).toList(),
      );
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final resultJson = await backend.computeProfileStats(historyJson, nowMs);
      return ProfileViewingStats.fromJson(
        jsonDecode(resultJson) as Map<String, dynamic>,
      );
    });

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
