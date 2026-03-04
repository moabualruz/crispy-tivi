import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/nav_arrow.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../favorites/data/favorites_history_service.dart';
import '../../domain/entities/channel.dart';

/// Horizontal strip of recently watched channels.
///
/// Shows up to 10 recent channels with circular logos and names.
/// Hidden automatically when [FavoritesHistoryState.recentlyWatched]
/// is empty, and when the channel list is in search or filtered mode.
///
/// Spec: FE-TV-01.
class RecentChannelsStrip extends ConsumerStatefulWidget {
  const RecentChannelsStrip({
    super.key,
    required this.onChannelTap,
    this.maxItems = 10,
  });

  /// Called when the user taps a recent channel tile.
  final void Function(Channel) onChannelTap;

  /// Maximum number of recent channels to display.
  final int maxItems;

  @override
  ConsumerState<RecentChannelsStrip> createState() =>
      _RecentChannelsStripState();
}

class _RecentChannelsStripState extends ConsumerState<RecentChannelsStrip> {
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
    final recent = ref.watch(
      favoritesHistoryProvider.select((s) => s.recentlyWatched),
    );
    if (recent.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final items = recent.take(widget.maxItems).toList();
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: CrispySpacing.md,
              top: CrispySpacing.sm,
              bottom: CrispySpacing.xs,
            ),
            child: Text(
              'Recently Watched',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: SizedBox(
              height: 88,
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.md,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final ch = items[index];
                      return _RecentChannelTile(
                        channel: ch,
                        onTap: () => widget.onChannelTap(ch),
                        autofocus: index == 0,
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
          Divider(
            height: CrispySpacing.sm,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

/// A single tile in the [RecentChannelsStrip].
class _RecentChannelTile extends StatelessWidget {
  const _RecentChannelTile({
    required this.channel,
    required this.onTap,
    this.autofocus = false,
  });

  final Channel channel;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.only(right: CrispySpacing.sm),
      child: FocusWrapper(
        onSelect: onTap,
        autofocus: autofocus,
        borderRadius: CrispyRadius.tv,
        semanticLabel: channel.name,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: SmartImage(
                    itemId: channel.id,
                    title: channel.name,
                    imageUrl: channel.logoUrl,
                    imageKind: 'logo',
                    fit: BoxFit.contain,
                    icon: Icons.live_tv,
                    placeholderAspectRatio: 1,
                    memCacheWidth: 96,
                  ),
                ),
              ),
              const SizedBox(height: CrispySpacing.xs),
              Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tt.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
