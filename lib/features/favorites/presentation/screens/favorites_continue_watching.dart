import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/domain/entities/watch_history_entry.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/utils/cw_filter_utils.dart';

// FE-FAV-09: VOD poster dimensions (2:3 portrait ratio).
const double kPosterWidth = 56.0;
const double kPosterHeight = 84.0;

/// FE-FAV-04: Formats a duration as "Xm left" or "Xh Ym left".
String formatTimeRemaining(Duration remaining) {
  final totalMinutes = remaining.inMinutes;
  if (totalMinutes <= 0) return '';
  if (totalMinutes < 60) return '${totalMinutes}m left';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '${hours}h left';
  return '${hours}h ${minutes}m left';
}

// ── Continue Watching tab ─────────────────────────────────────

/// Continue-watching VOD items tab.
///
/// FE-FAV-03: Adds status filter chips (All / Watching / Completed)
/// above the list.
///
/// FE-FAV-04: Shows estimated time remaining on each item.
///
/// Uses a 2-column grid on screens ≥ 840 dp (F-09).
///
/// Data source: [continueWatchingMoviesProvider] and
/// [continueWatchingSeriesProvider] — persisted Rust/SQLite backend.
class ContinueWatchingTab extends ConsumerStatefulWidget {
  const ContinueWatchingTab({super.key});

  @override
  ConsumerState<ContinueWatchingTab> createState() =>
      _ContinueWatchingTabState();
}

class _ContinueWatchingTabState extends ConsumerState<ContinueWatchingTab> {
  CwFilter _activeFilter = CwFilter.all;

  List<WatchHistoryEntry> _applyFilter(List<WatchHistoryEntry> entries) =>
      filterByCwStatus(entries, _activeFilter);

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(continueWatchingMoviesProvider);
    final seriesAsync = ref.watch(continueWatchingSeriesProvider);

    final isLoading = moviesAsync.isLoading || seriesAsync.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final movies = moviesAsync.value ?? const [];
    final series = seriesAsync.value ?? const [];

    // Combine and dedup by id, sort by most recently watched first.
    final seen = <String>{};
    final all =
        [...movies, ...series].where((e) => seen.add(e.id)).toList()
          ..sort((a, b) => b.lastWatched.compareTo(a.lastWatched));

    if (all.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.play_circle_outline,
        title: 'No items to continue',
      );
    }

    final filtered = _applyFilter(all);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ContinueWatchingFilterChipRow(
          activeFilter: _activeFilter,
          onFilterChanged: (filter) {
            setState(() => _activeFilter = filter);
          },
        ),
        Expanded(
          child:
              filtered.isEmpty
                  ? EmptyStateWidget(
                    icon: Icons.filter_list_off,
                    title: 'No ${_activeFilter.label.toLowerCase()} items',
                  )
                  : ResponsiveLayout(
                    compactBody: _buildList(
                      context,
                      items: filtered,
                      crossAxisCount: 1,
                    ),
                    largeBody: _buildList(
                      context,
                      items: filtered,
                      crossAxisCount: 2,
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context, {
    required List<WatchHistoryEntry> items,
    required int crossAxisCount,
  }) {
    Widget itemBuilder(BuildContext ctx, int index) {
      final entry = items[index];
      final remainingMs = entry.durationMs - entry.positionMs;
      final remaining =
          remainingMs > 0 ? Duration(milliseconds: remainingMs) : null;

      return ContinueWatchingItem(
        entry: entry,
        timeRemaining: remaining,
        onSelect: () {
          ref
              .read(playbackSessionProvider.notifier)
              .startPlayback(
                streamUrl: entry.streamUrl,
                channelName: entry.name,
                posterUrl: entry.posterUrl,
                startPosition:
                    entry.positionMs > 0
                        ? Duration(milliseconds: entry.positionMs)
                        : Duration.zero,
              );
        },
        onMarkWatched: () async {
          await ref
              .read(watchHistoryServiceProvider)
              .updatePosition(entry.id, entry.durationMs);
          // Invalidate providers so the list refreshes.
          ref.invalidate(continueWatchingMoviesProvider);
          ref.invalidate(continueWatchingSeriesProvider);
        },
      );
    }

    if (crossAxisCount == 1) {
      return ListView.builder(
        padding: const EdgeInsets.all(CrispySpacing.md),
        itemCount: items.length,
        itemBuilder: itemBuilder,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(CrispySpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: CrispySpacing.sm,
        mainAxisSpacing: CrispySpacing.sm,
        childAspectRatio: 4.5,
      ),
      itemCount: items.length,
      itemBuilder: itemBuilder,
    );
  }
}

// ── Filter chip row ───────────────────────────────────────────

/// FE-FAV-03: Horizontal row of [FilterChip]s for All / Watching / Completed.
class ContinueWatchingFilterChipRow extends StatelessWidget {
  const ContinueWatchingFilterChipRow({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final CwFilter activeFilter;
  final ValueChanged<CwFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.xs,
        ),
        children:
            CwFilter.values.map((filter) {
              final selected = filter == activeFilter;
              return Padding(
                padding: const EdgeInsets.only(right: CrispySpacing.sm),
                child: FilterChip(
                  label: Text(filter.label),
                  selected: selected,
                  onSelected: (_) => onFilterChanged(filter),
                  selectedColor: cs.primaryContainer,
                  checkmarkColor: cs.onPrimaryContainer,
                  labelStyle: TextStyle(
                    color: selected ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                  side: BorderSide(color: selected ? cs.primary : cs.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CrispyRadius.full),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

// ── Continue Watching item ────────────────────────────────────

/// F-06: Extracted continue-watching item row with progress bar.
///
/// FE-FAV-04: Shows [timeRemaining] as "Xm left" / "Xh Ym left".
/// FE-FAV-07: Long-press opens a context menu with "Mark as Watched".
/// FE-FAV-09: Poster thumbnail (56×84 dp, 2:3 ratio).
class ContinueWatchingItem extends StatelessWidget {
  const ContinueWatchingItem({
    super.key,
    required this.entry,
    this.timeRemaining,
    required this.onSelect,
    this.onMarkWatched,
  });

  final WatchHistoryEntry entry;
  final Duration? timeRemaining;
  final VoidCallback onSelect;
  final VoidCallback? onMarkWatched;

  void _showContextMenu(BuildContext context) async {
    final RenderBox itemBox = context.findRenderObject()! as RenderBox;
    final Offset topLeft = itemBox.localToGlobal(Offset.zero);
    final RelativeRect position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      topLeft.dx + itemBox.size.width,
      topLeft.dy + itemBox.size.height,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CrispyRadius.md),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'mark_watched',
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 20),
              const SizedBox(width: CrispySpacing.sm),
              const Text('Mark as Watched'),
            ],
          ),
        ),
      ],
    );

    if (result == 'mark_watched') {
      onMarkWatched?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progressPercent = '${(entry.progress * 100).toInt()}% watched';
    final timeLabel =
        timeRemaining != null ? formatTimeRemaining(timeRemaining!) : null;
    final hasPoster = entry.posterUrl != null && entry.posterUrl!.isNotEmpty;
    final posterUrl =
        entry.posterUrl?.isNotEmpty == true
            ? entry.posterUrl
            : entry.seriesPosterUrl;

    return Card(
      margin: const EdgeInsets.only(bottom: CrispySpacing.sm),
      shape: const RoundedRectangleBorder(),
      child: FocusWrapper(
        onSelect: onSelect,
        borderRadius: CrispyRadius.none,
        child: GestureDetector(
          onLongPress: () => _showContextMenu(context),
          child: ListTile(
            leading:
                hasPoster
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(CrispyRadius.sm),
                      child: SizedBox(
                        width: kPosterWidth,
                        height: kPosterHeight,
                        child: SmartImage(
                          itemId: entry.id,
                          title: entry.name,
                          imageUrl: posterUrl,
                          imageKind: 'poster',
                          fit: BoxFit.cover,
                          icon: Icons.movie_outlined,
                          memCacheWidth: kPosterWidth.toInt() * 2,
                          memCacheHeight: kPosterHeight.toInt() * 2,
                        ),
                      ),
                    )
                    : const Icon(Icons.play_circle, size: 40),
            isThreeLine: hasPoster,
            title: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (timeLabel != null && timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  )
                else
                  Text(progressPercent),
                const SizedBox(height: CrispySpacing.xs),
                Semantics(
                  label: 'Watch progress: $progressPercent',
                  child: LinearProgressIndicator(
                    value: entry.progress,
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
