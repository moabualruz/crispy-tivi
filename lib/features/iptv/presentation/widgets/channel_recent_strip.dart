import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/horizontal_scroll_row.dart';
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
class RecentChannelsStrip extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(
      favoritesHistoryProvider.select((s) => s.recentlyWatched),
    );
    if (recent.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final items = recent.take(maxItems).toList();
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
          HorizontalScrollRow<Channel>(
            items: items,
            itemWidth: 64,
            sectionHeight: 88,
            itemSpacing: 0,
            arrowWidth: 36,
            arrowIconSize: 20,
            itemBuilder:
                (ctx, ch, index) => _RecentChannelTile(
                  channel: ch,
                  onTap: () => onChannelTap(ch),
                  autofocus: index == 0,
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
        focusStyle: FocusIndicatorStyle.card,
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
