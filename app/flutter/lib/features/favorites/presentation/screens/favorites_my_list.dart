import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

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
/// Renders an inline search field at the top that filters both
/// channel and VOD sections by name as the user types (debounced
/// 500 ms, case-insensitive). Reads [favoritesControllerProvider]
/// for favorite channels and [vodProvider] for favorite VOD items
/// (movies + series). Each section appears only when it has
/// content after filtering; an empty-state placeholder is shown
/// when both sections are empty.
class MyFavoritesTab extends ConsumerStatefulWidget {
  const MyFavoritesTab({super.key});

  @override
  ConsumerState<MyFavoritesTab> createState() => _MyFavoritesTabState();
}

class _MyFavoritesTabState extends ConsumerState<MyFavoritesTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _searchQuery = value.trim().toLowerCase());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final favChannelsAsync = ref.watch(favoritesControllerProvider);
    final vodState = ref.watch(vodProvider);

    final allFavChannels = favChannelsAsync.asData?.value ?? [];
    final allFavVods = vodState.items.where((v) => v.isFavorite).toList();

    // Apply filter when a query is active.
    final favChannels =
        _searchQuery.isEmpty
            ? allFavChannels
            : allFavChannels
                .where((c) => c.name.toLowerCase().contains(_searchQuery))
                .toList();

    final favVods =
        _searchQuery.isEmpty
            ? allFavVods
            : allFavVods
                .where((v) => v.name.toLowerCase().contains(_searchQuery))
                .toList();

    final hasContent = allFavChannels.isNotEmpty || allFavVods.isNotEmpty;
    final hasResults = favChannels.isNotEmpty || favVods.isNotEmpty;

    if (!hasContent) {
      return EmptyStateWidget(
        icon: Icons.favorite_border,
        title: context.l10n.favoritesEmpty,
        description:
            'Add channels or shows to your favorites to see them here.',
      );
    }

    return CustomScrollView(
      slivers: [
        // ── Search field ────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            CrispySpacing.md,
            CrispySpacing.md,
            CrispySpacing.md,
            CrispySpacing.sm,
          ),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Filter favorites...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear filter',
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                        : null,
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CrispyRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                  vertical: CrispySpacing.sm,
                ),
              ),
            ),
          ),
        ),

        // ── No results after filtering ───────────────────────────
        if (!hasResults)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(CrispySpacing.xl),
                child: Text(
                  'No favorites match "$_searchQuery".',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

        // ── Channels section ────────────────────────────────────
        if (favChannels.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(title: 'Channels (${favChannels.length})'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xs)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
            sliver: SliverList.builder(
              itemCount: favChannels.length,
              itemBuilder: (ctx, index) {
                final channel = favChannels[index];
                return RecentlyWatchedItem(
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
                          sourceId: channel.sourceId,
                        );
                  },
                  onRemove: () {
                    ref
                        .read(favoritesControllerProvider.notifier)
                        .toggleFavorite(channel);
                  },
                  onLongPress: () {},
                  onToggleSelect: () {},
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.md)),
        ],

        // ── VOD section ─────────────────────────────────────────
        if (favVods.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Movies & Series (${favVods.length})',
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xs)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
            sliver: SliverList.builder(
              itemCount: favVods.length,
              itemBuilder:
                  (ctx, index) => _VodFavoriteItem(vod: favVods[index]),
            ),
          ),
        ],

        const SliverPadding(
          padding: EdgeInsets.only(bottom: CrispySpacing.md),
          sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
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
            tooltip: context.l10n.contextMenuRemoveFromFavorites,
          ),
        ),
      ),
    );
  }
}
