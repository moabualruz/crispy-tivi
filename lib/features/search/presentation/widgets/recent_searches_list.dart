import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../domain/entities/search_history_entry.dart';

/// Thumbnail size for search history entries (FE-SR-07).
const double _kThumbnailSize = 40.0;

/// Displays recent search history when no query is entered.
///
/// FE-SR-07: Each entry shows a thumbnail when available.
/// - Channel queries: channel logo (circle).
/// - VOD queries: poster thumbnail (rounded square).
/// - Text-only (no resolved match): search icon.
class RecentSearchesList extends StatelessWidget {
  const RecentSearchesList({
    super.key,
    required this.entries,
    required this.onSelect,
    required this.onRemove,
    required this.onClearAll,
  });

  /// List of recent search entries.
  final List<SearchHistoryEntry> entries;

  /// Called when a search entry is selected.
  final void Function(SearchHistoryEntry entry) onSelect;

  /// Called when a search entry should be removed.
  final void Function(String id) onRemove;

  /// Called when all history should be cleared.
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: CrispySpacing.md),
            Text(
              'Search for channels, movies, series, or programs',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(onPressed: onClearAll, child: const Text('Clear All')),
            ],
          ),
        ),

        // History list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _HistoryItem(
                entry: entry,
                onTap: () => onSelect(entry),
                onRemove: () => onRemove(entry.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  final SearchHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      // FE-SR-07: thumbnail when available, search icon otherwise.
      leading: _ThumbnailLeading(entry: entry),
      title: Text(entry.query, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Text(
            formatRelativeTime(entry.searchedAt),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (entry.resultCount > 0) ...[
            const Text(' • '),
            Text(
              '${entry.resultCount} results',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 20),
        onPressed: onRemove,
        tooltip: 'Remove from history',
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
    );
  }
}

/// FE-SR-07: Leading widget for a search history item.
///
/// Shows a channel logo (circle), VOD poster (rounded square),
/// or a generic search icon depending on [SearchHistoryEntry.resultType].
class _ThumbnailLeading extends StatelessWidget {
  const _ThumbnailLeading({required this.entry});

  final SearchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final thumbnailUrl = entry.thumbnailUrl;
    final resultType = entry.resultType;

    // No resolved match → generic search icon.
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      return Icon(Icons.history, color: colorScheme.onSurfaceVariant);
    }

    // Channel logo → circle clip.
    if (resultType == SearchHistoryResultType.channel) {
      return ClipOval(
        child: SizedBox(
          width: _kThumbnailSize,
          height: _kThumbnailSize,
          child: SmartImage(
            itemId: entry.id,
            title: entry.query,
            imageUrl: thumbnailUrl,
            imageKind: 'logo',
            fit: BoxFit.cover,
            icon: Icons.tv,
            memCacheWidth: _kThumbnailSize.toInt() * 2,
          ),
        ),
      );
    }

    // VOD poster → rounded square.
    return ClipRRect(
      borderRadius: BorderRadius.circular(CrispyRadius.xs),
      child: SizedBox(
        width: _kThumbnailSize,
        height: _kThumbnailSize,
        child: SmartImage(
          itemId: entry.id,
          title: entry.query,
          imageUrl: thumbnailUrl,
          imageKind: 'poster',
          fit: BoxFit.cover,
          icon: Icons.movie_outlined,
          memCacheWidth: _kThumbnailSize.toInt() * 2,
        ),
      ),
    );
  }
}
