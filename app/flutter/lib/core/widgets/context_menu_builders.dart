import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';

import 'context_menu_panel.dart';

/// Builds context menu sections for a Channel.
///
/// Used in channel list, home screen, and EPG screens.
List<ContextMenuSection> buildChannelContextMenu({
  required BuildContext context,
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

  /// Shows "Smart Group" item — manage cross-provider groups.
  VoidCallback? onSmartGroup,

  /// Shows "Multi-View" item — opens multi-view grid.
  VoidCallback? onMultiView,
}) {
  return [
    ContextMenuSection(
      header: channelName,
      headerColor: colorScheme.primary,
      items: [
        ContextMenuItem(
          icon: isFavorite ? Icons.star : Icons.star_outline,
          label:
              isFavorite
                  ? context.l10n.contextMenuRemoveFavorite
                  : context.l10n.contextMenuAddFavorite,
          onTap: onToggleFavorite,
        ),
        if (onSwitchStream != null)
          ContextMenuItem(
            icon: Icons.switch_video_outlined,
            label: context.l10n.contextMenuSwitchStream,
            onTap: onSwitchStream,
          ),
        if (onSmartGroup != null)
          ContextMenuItem(
            icon: Icons.bolt,
            label: context.l10n.contextMenuSmartGroup,
            onTap: onSmartGroup,
          ),
        if (onMultiView != null)
          ContextMenuItem(
            icon: Icons.grid_view_rounded,
            label: context.l10n.contextMenuMultiView,
            onTap: onMultiView,
          ),
        if (onAssignEpg != null)
          ContextMenuItem(
            icon: Icons.tv_rounded,
            label: context.l10n.contextMenuAssignEpg,
            onTap: onAssignEpg,
          ),
        if (onHide != null)
          ContextMenuItem(
            icon: Icons.visibility_off,
            label: context.l10n.contextMenuHideChannel,
            onTap: onHide,
          ),
        if (onCopyUrl != null)
          ContextMenuItem(
            icon: Icons.copy,
            label: context.l10n.contextMenuCopyUrl,
            onTap: onCopyUrl,
          ),
        if (onOpenExternal != null)
          ContextMenuItem(
            icon: Icons.open_in_new,
            label: context.l10n.contextMenuOpenExternal,
            onTap: onOpenExternal,
          ),
        if (onBlock != null)
          ContextMenuItem(
            icon: Icons.block,
            label: context.l10n.contextMenuBlockChannel,
            isDestructive: true,
            onTap: onBlock,
          ),
      ],
    ),
  ];
}

/// Builds context menu sections for a Movie.
List<ContextMenuSection> buildMovieContextMenu({
  required BuildContext context,
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
        ContextMenuItem(
          icon: Icons.play_arrow,
          label: context.l10n.contextMenuPlay,
          onTap: onPlay,
        ),
        ContextMenuItem(
          icon: isFavorite ? Icons.star : Icons.star_outline,
          label:
              isFavorite
                  ? context.l10n.contextMenuRemoveFavorite
                  : context.l10n.contextMenuAddFavorite,
          onTap: onToggleFavorite,
        ),
        if (onViewDetails != null)
          ContextMenuItem(
            icon: Icons.info_outline,
            label: context.l10n.contextMenuViewDetails,
            onTap: onViewDetails,
          ),
        if (onCopyUrl != null)
          ContextMenuItem(
            icon: Icons.copy,
            label: context.l10n.contextMenuCopyUrl,
            onTap: onCopyUrl,
          ),
        if (onOpenExternal != null)
          ContextMenuItem(
            icon: Icons.open_in_new,
            label: context.l10n.contextMenuOpenExternal,
            onTap: onOpenExternal,
          ),
      ],
    ),
  ];
}

/// Builds context menu sections for a Series.
List<ContextMenuSection> buildSeriesContextMenu({
  required BuildContext context,
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
          label:
              isFavorite
                  ? context.l10n.contextMenuRemoveFavorite
                  : context.l10n.contextMenuAddFavorite,
          onTap: onToggleFavorite,
        ),
        if (onViewDetails != null)
          ContextMenuItem(
            icon: Icons.info_outline,
            label: context.l10n.contextMenuViewDetails,
            onTap: onViewDetails,
          ),
      ],
    ),
  ];
}

/// Builds context menu sections for a Category.
List<ContextMenuSection> buildCategoryContextMenu({
  required BuildContext context,
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
                  ? context.l10n.contextMenuRemoveFavoriteCategory
                  : context.l10n.contextMenuAddFavoriteCategory,
          onTap: onToggleFavorite,
        ),
        if (onFilter != null)
          ContextMenuItem(
            icon: Icons.filter_list,
            label: context.l10n.contextMenuFilterCategory,
            onTap: onFilter,
          ),
      ],
    ),
  ];
}

/// Builds context menu for a series Episode.
List<ContextMenuSection> buildEpisodeContextMenu({
  required BuildContext context,
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
        ContextMenuItem(
          icon: Icons.play_arrow,
          label: context.l10n.contextMenuPlay,
          onTap: onPlay,
        ),
        if (onCopyUrl != null)
          ContextMenuItem(
            icon: Icons.copy,
            label: context.l10n.contextMenuCopyUrl,
            onTap: onCopyUrl,
          ),
        if (onOpenExternal != null)
          ContextMenuItem(
            icon: Icons.open_in_new,
            label: context.l10n.contextMenuOpenExternal,
            onTap: onOpenExternal,
          ),
      ],
    ),
  ];
}
