import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/watch_progress_bar.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/domain/entities/watch_history_entry.dart';

// FE-PM-05: poster dimensions (2:3 portrait ratio).
const double _kPosterWidth = 56.0;
const double _kPosterHeight = 84.0;

/// Provider that loads all watch history entries for a specific profile.
///
/// Watches [watchHistoryServiceProvider] so it re-evaluates when
/// the active profile changes.
final profileWatchHistoryProvider = FutureProvider.family
    .autoDispose<List<WatchHistoryEntry>, String>((ref, profileId) async {
      final service = ref.watch(watchHistoryServiceProvider);
      final all = await service.getAll();
      // Filter by profile and return most recent first.
      return all.where((e) => e.profileId == profileId).toList();
    });

/// Per-profile watch history screen.
///
/// Shows all [WatchHistoryEntry] items recorded for [profileId],
/// sorted by most recently watched first. Each row displays:
/// - poster thumbnail (or media-type icon fallback)
/// - title + episode label (for series)
/// - watched date
/// - playback progress bar (for movies/episodes)
///
/// FE-PM-05 spec requirement.
class ProfileWatchHistoryScreen extends ConsumerWidget {
  const ProfileWatchHistoryScreen({
    required this.profileId,
    required this.profileName,
    super.key,
  });

  /// The profile whose history is shown.
  final String profileId;

  /// Display name used in the AppBar title.
  final String profileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(profileWatchHistoryProvider(profileId));

    return Scaffold(
      key: TestKeys.profileWatchHistoryScreen,
      appBar: AppBar(
        title: Text("$profileName's History"),
        actions: [
          historyAsync.whenOrNull(
                data:
                    (entries) =>
                        entries.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.delete_sweep),
                              tooltip: 'Clear history',
                              onPressed:
                                  () => _confirmClearHistory(
                                    context,
                                    ref,
                                    entries,
                                  ),
                            )
                            : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: historyAsync.when(
        loading: () => const LoadingStateWidget(),
        error:
            (err, _) => Center(
              child: Text(
                'Error loading history: $err',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        data: (entries) => _buildList(context, ref, entries),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<WatchHistoryEntry> entries,
  ) {
    if (entries.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history,
        title: 'No watch history',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(CrispySpacing.md),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _WatchHistoryItem(
          entry: entries[index],
          onDelete: () => _deleteEntry(ref, entries[index].id),
        );
      },
    );
  }

  Future<void> _confirmClearHistory(
    BuildContext context,
    WidgetRef ref,
    List<WatchHistoryEntry> entries,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Clear Watch History'),
            content: Text(
              'Remove all ${entries.length} history '
              "entries for $profileName?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;
    // Delete each entry for this profile.
    final service = ref.read(watchHistoryServiceProvider);
    for (final entry in entries) {
      await service.delete(entry.id);
    }
    // Invalidate to refresh the list.
    ref.invalidate(profileWatchHistoryProvider(profileId));
  }

  Future<void> _deleteEntry(WidgetRef ref, String entryId) async {
    final service = ref.read(watchHistoryServiceProvider);
    await service.delete(entryId);
    ref.invalidate(profileWatchHistoryProvider(profileId));
  }
}

/// Single row in the profile watch history list.
///
/// Shows poster, title, episode label, watched date,
/// and a linear progress bar for VOD items.
class _WatchHistoryItem extends StatelessWidget {
  const _WatchHistoryItem({required this.entry, required this.onDelete});

  final WatchHistoryEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasPoster = entry.posterUrl != null && entry.posterUrl!.isNotEmpty;
    final hasProgress = entry.durationMs > 0 && entry.mediaType != 'channel';
    final watchedDate = formatRelativeTime(entry.lastWatched);

    // Subtitle: episode label + watched date.
    final subtitleParts = <String>[];
    final ep = entry.episodeLabel;
    if (ep != null) subtitleParts.add(ep);
    subtitleParts.add(watchedDate);
    final subtitle = subtitleParts.join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: CrispySpacing.sm),
      shape: const RoundedRectangleBorder(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.xs,
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
          child: SizedBox(
            width: _kPosterWidth,
            height: _kPosterHeight,
            child:
                hasPoster
                    ? SmartImage(
                      itemId: entry.id,
                      title: entry.name,
                      imageUrl: entry.posterUrl,
                      imageKind: 'poster',
                      fit: BoxFit.cover,
                      icon: _mediaIcon(entry.mediaType),
                      memCacheWidth: _kPosterWidth.toInt() * 2,
                      memCacheHeight: _kPosterHeight.toInt() * 2,
                    )
                    : Container(
                      color: cs.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        _mediaIcon(entry.mediaType),
                        color: cs.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
          ),
        ),
        isThreeLine: hasProgress,
        title: Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.bodyMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasProgress) ...[
              const SizedBox(height: CrispySpacing.xs),
              Semantics(
                label:
                    'Watch progress: '
                    '${(entry.progress * 100).toInt()}%',
                child: WatchProgressBar(
                  value: entry.progress,
                  height: 3,
                  fillColor: CrispyColors.brandRed,
                  backgroundColor: cs.outlineVariant,
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: onDelete,
          tooltip: 'Remove from history',
        ),
      ),
    );
  }

  IconData _mediaIcon(String mediaType) {
    switch (mediaType) {
      case 'channel':
        return Icons.live_tv;
      case 'episode':
        return Icons.video_library_outlined;
      default:
        return Icons.movie_outlined;
    }
  }
}
