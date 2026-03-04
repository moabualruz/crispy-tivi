import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/nav_arrow.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../providers/watchlist_provider.dart';

// FE-H-01: My List / Watchlist row on the home screen.

/// Horizontal "My List" row displayed below the hero banner.
///
/// Hidden entirely when the watchlist is empty.
/// Each card shows the poster thumbnail and title.
/// Long-press reveals a remove-from-watchlist action.
class MyListSection extends ConsumerStatefulWidget {
  const MyListSection({super.key});

  @override
  ConsumerState<MyListSection> createState() => _MyListSectionState();
}

class _MyListSectionState extends ConsumerState<MyListSection> {
  final _scrollController = ScrollController();
  bool _isHovered = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.enterCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(watchlistProvider).value?.items ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CrispySpacing.md,
            CrispySpacing.xl,
            CrispySpacing.md,
            CrispySpacing.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.playlist_play_rounded, size: 20, color: cs.primary),
              const SizedBox(width: CrispySpacing.sm),
              Expanded(
                child: Text(
                  'My List',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: SizedBox(
            height: _kCardHeight + CrispySpacing.md * 2 + 32,
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.md,
                    vertical: CrispySpacing.sm,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    return Padding(
                      padding: const EdgeInsets.only(right: CrispySpacing.sm),
                      child: _WatchlistCard(item: items[i]),
                    );
                  },
                ),
                if (_isHovered)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 36,
                    child: NavArrow(
                      icon: Icons.chevron_left,
                      onTap: () => _scrollBy(-200),
                      isLeft: true,
                      iconSize: 20,
                    ),
                  ),
                if (_isHovered)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 36,
                    child: NavArrow(
                      icon: Icons.chevron_right,
                      onTap: () => _scrollBy(200),
                      isLeft: false,
                      iconSize: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

const double _kCardWidth = 120.0;
const double _kCardHeight = 180.0;

/// A single card in the My List row.
///
/// - Tap → opens the VOD detail or series detail screen.
/// - Long-press → shows a bottom sheet with "Remove from My List".
class _WatchlistCard extends ConsumerStatefulWidget {
  const _WatchlistCard({required this.item});

  final VodItem item;

  @override
  ConsumerState<_WatchlistCard> createState() => _WatchlistCardState();
}

class _WatchlistCardState extends ConsumerState<_WatchlistCard> {
  bool _isHovered = false;

  void _tap() {
    final item = widget.item;
    final tag = '${item.id}_mylist';
    if (item.type == VodType.movie) {
      context.push(AppRoutes.vodDetails, extra: {'item': item, 'heroTag': tag});
    } else {
      context.push(AppRoutes.seriesDetail, extra: item);
    }
  }

  void _onLongPress() {
    final item = widget.item;
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CrispyRadius.md),
        ),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: CrispySpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(CrispyRadius.full),
                ),
              ),
              const SizedBox(height: CrispySpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                ),
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(sheetCtx).textTheme.titleSmall,
                ),
              ),
              const Divider(height: CrispySpacing.lg),
              ListTile(
                leading: Icon(Icons.remove_circle_outline, color: cs.error),
                title: const Text('Remove from My List'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  ref.read(watchlistProvider.notifier).remove(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed "${item.name}" from My List'),
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed:
                            () =>
                                ref.read(watchlistProvider.notifier).add(item),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: CrispySpacing.sm),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _tap,
        onLongPress: _onLongPress,
        child: AnimatedScale(
          scale: _isHovered ? CrispyAnimation.hoverScale : 1.0,
          duration: CrispyAnimation.fast,
          curve: CrispyAnimation.focusCurve,
          child: SizedBox(
            width: _kCardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  child: SizedBox(
                    width: _kCardWidth,
                    height: _kCardHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SmartImage(
                          itemId: item.id,
                          title: item.name,
                          imageUrl: item.posterUrl,
                          imageKind: 'poster',
                          fit: BoxFit.cover,
                          icon:
                              item.type == VodType.movie
                                  ? Icons.movie_outlined
                                  : Icons.tv,
                          memCacheWidth: 200,
                        ),
                        // Remove button overlay — visible on hover.
                        AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.0,
                          duration: CrispyAnimation.fast,
                          child: Positioned.fill(
                            child: ColoredBox(
                              color: cs.surface.withValues(alpha: 0.55),
                              child: Center(
                                child: Icon(
                                  Icons.close_rounded,
                                  color: cs.onSurface,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: CrispySpacing.xs),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
