import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';

/// Single channel row with logo, name, now-playing
/// info, and resolution badge.
class EpgChannelRow extends StatelessWidget {
  const EpgChannelRow({
    required this.channel,
    this.nowPlaying,
    this.isSelected = false,
    this.isPlaying = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Channel channel;
  final EpgEntry? nowPlaying;
  final bool isSelected;

  /// Whether this channel is currently playing.
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onLongPress: onLongPress,
      child: FocusWrapper(
        onSelect: onTap,
        borderRadius: CrispyRadius.none,
        semanticLabel:
            channel.number != null
                ? 'Channel ${channel.number}, ${channel.name}'
                : channel.name,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.sm,
            vertical: CrispySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : null,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
          ),
          child: Row(
            children: [
              // Channel number
              if (channel.number != null)
                SizedBox(
                  width: 32,
                  child: Text(
                    '${channel.number}',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.only(right: CrispySpacing.xs),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: SmartImage(
                    itemId: channel.id,
                    title: channel.name,
                    imageUrl: channel.logoUrl,
                    imageKind: 'logo',
                    fit: BoxFit.contain,
                    memCacheWidth: 56,
                    memCacheHeight: 56,
                  ),
                ),
              ),

              // Channel name + now playing
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPlaying) ...[
                          Icon(
                            Icons.play_arrow,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: CrispySpacing.xxs),
                        ],
                        Flexible(
                          child: Text(
                            channel.name,
                            style: textTheme.bodySmall?.copyWith(
                              color: isPlaying ? colorScheme.primary : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (nowPlaying != null)
                      Text(
                        nowPlaying!.title,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Resolution badge
              if (channel.resolution != null)
                Container(
                  margin: const EdgeInsets.only(left: CrispySpacing.xs),
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.xs,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    channel.resolution!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
