import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
import 'package:crispy_tivi/core/widgets/context_menu_builders.dart';
import 'package:crispy_tivi/core/widgets/context_menu_panel.dart';
import '../../utils/media_item_vod_adapter.dart';
import '../../../../vod/presentation/widgets/vod_poster_card.dart';
import 'media_item_quality_badge.dart';

/// A poster card for an item inside a media-server library.
///
/// - Folders and series navigate deeper into `/$routeBase/library/{id}`.
/// - Playable items (movies, episodes, etc.) open [AppRoutes.mediaServerDetails].
/// - Long-press opens a TiviMate-style slide-in context menu (FE-EB-09).
/// - Quality badges (4K, HDR, Dolby) are shown in the bottom-right corner
///   when quality metadata is available (FE-JF-11).
class MediaServerItemCard extends ConsumerWidget {
  const MediaServerItemCard({
    required this.item,
    required this.serverType,
    required this.getStreamUrl,
    required this.heroPrefix,
    super.key,
  });

  /// The media item to display.
  final MediaItem item;

  /// Server type used to build the details-screen route extra.
  final MediaServerType serverType;

  /// Callback that resolves a stream URL for the given item ID.
  final Future<String> Function(String itemId) getStreamUrl;

  /// Prefix for the hero animation tag, e.g. `'emby'` or `'jellyfin'`.
  ///
  /// Also used to derive the sub-library route: `/$heroPrefix/library/{id}`.
  final String heroPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VodPosterCard(
      item: item.toVodItem(streamUrl: ''), // Stream URL resolved on demand
      heroTag: '${heroPrefix}_${item.id}',
      progress: item.watchProgress,
      onTap: () => _onTap(context),
      onLongPress: () => _showContextMenu(context, ref),
      // FE-JF-11: quality badge overlay (4K / HDR / Dolby).
      overlayBuilder: (context, _) => MediaItemQualityBadge(item: item),
    );
  }

  void _onTap(BuildContext context) {
    if (item.type == MediaType.series) {
      // EB-FE-11 / JF-FE-12: Series → dedicated season+episode navigator.
      context.push(
        '/$heroPrefix/series/${item.id}'
        '?title=${Uri.encodeComponent(item.name)}',
      );
    } else if (item.type == MediaType.folder || item.type == MediaType.season) {
      context.push(
        '/$heroPrefix/library/${item.id}'
        '?title=${Uri.encodeComponent(item.name)}',
      );
    } else {
      context.push(
        AppRoutes.mediaServerDetails,
        extra: {
          'item': item,
          'serverType': serverType,
          'getStreamUrl': getStreamUrl,
          'heroTag': '${heroPrefix}_${item.id}',
        },
      );
    }
  }

  /// FE-EB-09: Long-press context menu — Play, Add to Queue, Mark as
  /// Watched, Favorite, View Details.
  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    showContextMenuPanel(
      context: context,
      sections: buildMediaServerItemContextMenu(
        itemName: item.name,
        colorScheme: colorScheme,
        isWatched: item.isWatched,
        isFavorite: false, // Media server favorites not yet tracked locally.
        onPlay: () => _navigateToDetails(context),
        onViewDetails: () => _navigateToDetails(context),
        // Queue and watched-toggle are informational for now; providers
        // for server-side watched status are not yet implemented.
        onAddToQueue: null,
        onToggleWatched: null,
        onToggleFavorite: null,
      ),
    );
  }

  /// Navigates to the media item details screen.
  void _navigateToDetails(BuildContext context) {
    if (item.type == MediaType.series) {
      // EB-FE-11 / JF-FE-12: Series → dedicated season+episode navigator.
      context.push(
        '/$heroPrefix/series/${item.id}'
        '?title=${Uri.encodeComponent(item.name)}',
      );
    } else if (item.type == MediaType.folder || item.type == MediaType.season) {
      context.push(
        '/$heroPrefix/library/${item.id}'
        '?title=${Uri.encodeComponent(item.name)}',
      );
    } else {
      context.push(
        AppRoutes.mediaServerDetails,
        extra: {
          'item': item,
          'serverType': serverType,
          'getStreamUrl': getStreamUrl,
          'heroTag': '${heroPrefix}_${item.id}',
        },
      );
    }
  }
}
