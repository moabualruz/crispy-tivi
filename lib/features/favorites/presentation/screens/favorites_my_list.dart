import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
import '../../presentation/providers/favorites_controller.dart';
import 'favorites_recently_watched.dart' show RecentlyWatchedItem;

// ── My Favorites tab ──────────────────────────────────────────

/// Tab showing the user's favorited channels and VOD items.
///
/// Reads [favoritesControllerProvider] for favorite channels and
/// [vodProvider] for favorite VOD items (movies + series).
/// Each section appears only when it has content; an empty-state
/// placeholder is shown when both sections are empty.
class MyFavoritesTab extends ConsumerWidget {
  const MyFavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favChannelsAsync = ref.watch(favoritesControllerProvider);
    final vodState = ref.watch(vodProvider);
    final favVods = vodState.items.where((v) => v.isFavorite).toList();
    final favChannels = favChannelsAsync.asData?.value ?? [];

    if (favChannels.isEmpty && favVods.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.favorite_border,
        title: 'No favorites yet',
        description:
            'Add channels or shows to your favorites to see them here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(CrispySpacing.md),
      children: [
        if (favChannels.isNotEmpty) ...[
          SectionHeader(title: 'Channels (${favChannels.length})'),
          const SizedBox(height: CrispySpacing.xs),
          ...favChannels.map(
            (channel) => RecentlyWatchedItem(
              channel: channel,
              isSelecting: false,
              isSelected: false,
              onPlay: () {
                ref
                    .read(playbackSessionProvider.notifier)
                    .startPlayback(
                      streamUrl: channel.streamUrl,
                      isLive: true,
                      channelName: channel.name,
                      channelLogoUrl: channel.logoUrl,
                    );
              },
              onRemove: () {
                ref
                    .read(favoritesControllerProvider.notifier)
                    .toggleFavorite(channel);
              },
              onLongPress: () {},
              onToggleSelect: () {},
            ),
          ),
          const SizedBox(height: CrispySpacing.md),
        ],
        if (favVods.isNotEmpty) ...[
          SectionHeader(title: 'Movies & Series (${favVods.length})'),
          const SizedBox(height: CrispySpacing.xs),
          ...favVods.map((vod) => _VodFavoriteItem(vod: vod)),
        ],
      ],
    );
  }
}

// ── VOD favorite item ─────────────────────────────────────────

/// A single favorited VOD item row.
///
/// Tapping plays the item; the trailing heart icon removes it from
/// favorites via [vodProvider].
class _VodFavoriteItem extends ConsumerWidget {
  const _VodFavoriteItem({required this.vod});

  final VodItem vod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: CrispySpacing.sm),
      shape: const RoundedRectangleBorder(),
      child: FocusWrapper(
        onSelect: () {
          ref
              .read(playbackSessionProvider.notifier)
              .startPlayback(
                streamUrl: vod.streamUrl,
                channelName: vod.name,
                posterUrl: vod.posterUrl,
              );
        },
        borderRadius: CrispyRadius.none,
        child: ListTile(
          leading: SizedBox(
            width: 48,
            height: 36,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CrispyRadius.xs),
              child: SmartImage(
                itemId: vod.id,
                title: vod.name,
                imageUrl: vod.posterUrl,
                imageKind: 'poster',
                fit: BoxFit.cover,
                icon: Icons.movie_outlined,
              ),
            ),
          ),
          title: Text(vod.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: vod.category != null ? Text(vod.category!) : null,
          trailing: IconButton(
            onPressed: () {
              ref.read(vodProvider.notifier).toggleFavorite(vod.id);
            },
            icon: Icon(Icons.favorite, size: 18, color: cs.error),
            tooltip: 'Remove from favorites',
          ),
        ),
      ),
    );
  }
}
