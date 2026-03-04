import 'package:flutter/material.dart';

import 'context_menu_panel.dart';

/// Builds context menu sections for a Channel.
///
/// Used in channel list, home screen, and EPG screens.
List<ContextMenuSection> buildChannelContextMenu({
  required String channelName,
  required bool isFavorite,
  required ColorScheme colorScheme,
  required VoidCallback onToggleFavorite,
  VoidCallback? onAssignEpg,
  VoidCallback? onHide,
  VoidCallback? onBlock,
  VoidCallback? onCopyUrl,
  VoidCallback? onOpenExternal,

  /// Shows "Switch stream" item — opens [StreamFailoverSheet].
  /// Supply when the channel has multiple backup stream URLs
  /// or to allow manual failover.
  VoidCallback? onSwitchStream,
}) {
  return [
    ContextMenuSection(
      header: channelName,
      headerColor: colorScheme.primary,
      items: [
        ContextMenuItem(
          icon: isFavorite ? Icons.star : Icons.star_outline,
          label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
          onTap: onToggleFavorite,
        ),
        if (onSwitchStream != null)
          ContextMenuItem(
            icon: Icons.switch_video_outlined,
            label: 'Switch stream source',
            onTap: onSwitchStream,
          ),
        if (onAssignEpg != null)
          ContextMenuItem(
            icon: Icons.tv_rounded,
            label: 'Assign EPG',
            onTap: onAssignEpg,
          ),
        if (onHide != null)
          ContextMenuItem(
            icon: Icons.visibility_off,
            label: 'Hide channel',
            onTap: onHide,
          ),
        if (onCopyUrl != null)
          ContextMenuItem(
            icon: Icons.copy,
            label: 'Copy Stream URL',
            onTap: onCopyUrl,
          ),
        if (onOpenExternal != null)
          ContextMenuItem(
            icon: Icons.open_in_new,
            label: 'Play in External Player',
            onTap: onOpenExternal,
          ),
        if (onBlock != null)
          ContextMenuItem(
            icon: Icons.block,
            label: 'Block channel',
            isDestructive: true,
            onTap: onBlock,
          ),
      ],
    ),
  ];
}

/// Builds context menu sections for a Movie.
List<ContextMenuSection> buildMovieContextMenu({
  required String movieName,
  required bool isFavorite,
  required ColorScheme colorScheme,
  required VoidCallback onToggleFavorite,
  required VoidCallback onPlay,
  VoidCallback? onViewDetails,
  VoidCallback? onCopyUrl,
  VoidCallback? onOpenExternal,
}) {
  return [
    ContextMenuSection(
      header: movieName,
      headerColor: colorScheme.primary,
      items: [
        ContextMenuItem(icon: Icons.play_arrow, label: 'Play', onTap: onPlay),
        ContextMenuItem(
          icon: isFavorite ? Icons.star : Icons.star_outline,
          label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
          onTap: onToggleFavorite,
        ),
        if (onViewDetails != null)
          ContextMenuItem(
            icon: Icons.info_outline,
            label: 'View details',
            onTap: onViewDetails,
          ),
        if (onCopyUrl != null)
          ContextMenuItem(
            icon: Icons.copy,
            label: 'Copy Stream URL',
            onTap: onCopyUrl,
          ),
        if (onOpenExternal != null)
          ContextMenuItem(
            icon: Icons.open_in_new,
            label: 'Play in External Player',
            onTap: onOpenExternal,
          ),
      ],
    ),
  ];
}

/// Builds context menu sections for a Series.
List<ContextMenuSection> buildSeriesContextMenu({
  required String seriesName,
  required bool isFavorite,
  required ColorScheme colorScheme,
  required VoidCallback onToggleFavorite,
  VoidCallback? onViewDetails,
}) {
  return [
    ContextMenuSection(
      header: seriesName,
      headerColor: colorScheme.primary,
      items: [
        ContextMenuItem(
          icon: isFavorite ? Icons.star : Icons.star_outline,
          label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
          onTap: onToggleFavorite,
        ),
        if (onViewDetails != null)
          ContextMenuItem(
            icon: Icons.info_outline,
            label: 'View details',
            onTap: onViewDetails,
          ),
      ],
    ),
  ];
}

/// Builds context menu sections for a Category.
List<ContextMenuSection> buildCategoryContextMenu({
  required String categoryName,
  required bool isFavorite,
  required ColorScheme colorScheme,
  required VoidCallback onToggleFavorite,
  VoidCallback? onFilter,
}) {
  return [
    ContextMenuSection(
      header: categoryName,
      headerColor: colorScheme.primary,
      items: [
        ContextMenuItem(
          icon: isFavorite ? Icons.star : Icons.star_outline,
          label:
              isFavorite
                  ? 'Remove from Favorite Categories'
                  : 'Add to Favorite Categories',
          onTap: onToggleFavorite,
        ),
        if (onFilter != null)
          ContextMenuItem(
            icon: Icons.filter_list,
            label: 'Filter by this category',
            onTap: onFilter,
          ),
      ],
    ),
  ];
}

/// Builds context menu sections for a media server library item.
///
/// Used in Plex, Emby, and Jellyfin library grids on long-press.
/// Actions: Play, Add to Queue, Mark as Watched/Unwatched, Favorite,
/// View Details.  Optional callbacks are omitted when null.
List<ContextMenuSection> buildMediaServerItemContextMenu({
  required String itemName,
  required ColorScheme colorScheme,
  required VoidCallback onPlay,
  required VoidCallback onViewDetails,
  bool isWatched = false,
  bool isFavorite = false,
  VoidCallback? onAddToQueue,
  VoidCallback? onToggleWatched,
  VoidCallback? onToggleFavorite,
}) {
  return [
    ContextMenuSection(
      header: itemName,
      headerColor: colorScheme.primary,
      items: [
        ContextMenuItem(icon: Icons.play_arrow, label: 'Play', onTap: onPlay),
        if (onAddToQueue != null)
          ContextMenuItem(
            icon: Icons.queue,
            label: 'Add to Queue',
            onTap: onAddToQueue,
          ),
        if (onToggleWatched != null)
          ContextMenuItem(
            icon:
                isWatched
                    ? Icons.visibility_off_outlined
                    : Icons.check_circle_outline,
            label: isWatched ? 'Mark as Unwatched' : 'Mark as Watched',
            onTap: onToggleWatched,
          ),
        if (onToggleFavorite != null)
          ContextMenuItem(
            icon: isFavorite ? Icons.star : Icons.star_outline,
            label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            onTap: onToggleFavorite,
          ),
        ContextMenuItem(
          icon: Icons.info_outline,
          label: 'View Details',
          onTap: onViewDetails,
        ),
      ],
    ),
  ];
}

/// Builds context menu for a series Episode.
List<ContextMenuSection> buildEpisodeContextMenu({
  required String episodeName,
  required ColorScheme colorScheme,
  required VoidCallback onPlay,
  VoidCallback? onCopyUrl,
  VoidCallback? onOpenExternal,
}) {
  return [
    ContextMenuSection(
      header: episodeName,
      headerColor: colorScheme.primary,
      items: [
        ContextMenuItem(icon: Icons.play_arrow, label: 'Play', onTap: onPlay),
        if (onCopyUrl != null)
          ContextMenuItem(
            icon: Icons.copy,
            label: 'Copy Stream URL',
            onTap: onCopyUrl,
          ),
        if (onOpenExternal != null)
          ContextMenuItem(
            icon: Icons.open_in_new,
            label: 'Play in External Player',
            onTap: onOpenExternal,
          ),
      ],
    ),
  ];
}
