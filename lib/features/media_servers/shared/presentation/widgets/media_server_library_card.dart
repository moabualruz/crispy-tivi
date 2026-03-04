import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import '../../utils/media_item_vod_adapter.dart';
import '../../../../vod/presentation/widgets/vod_poster_card.dart';

/// A poster card for a media-server library (Emby, Jellyfin, etc.).
///
/// Tapping navigates to `/$routeBase/library/{id}?title={name}`.
class MediaServerLibraryCard extends StatelessWidget {
  const MediaServerLibraryCard({
    required this.library,
    required this.heroPrefix,
    required this.routeBase,
    super.key,
  });

  /// The library item to display.
  final MediaItem library;

  /// Prefix for the hero animation tag, e.g. `'emby'` or `'jellyfin'`.
  final String heroPrefix;

  /// Route base segment, e.g. `'emby'` or `'jellyfin'`.
  final String routeBase;

  @override
  Widget build(BuildContext context) {
    return VodPosterCard(
      item: library.toVodItem(streamUrl: ''),
      heroTag: '${heroPrefix}_lib_${library.id}',
      onTap: () {
        context.push(
          '/$routeBase/library/${library.id}'
          '?title=${Uri.encodeComponent(library.name)}',
        );
      },
    );
  }
}
