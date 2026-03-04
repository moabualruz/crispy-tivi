import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/favorite_star_overlay.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../domain/entities/channel.dart';

/// A single channel row in the channel list.
///
/// Displays logo, name, current program, group badge,
/// and favorite indicator. Wraps in [FocusWrapper] for
/// TV D-pad navigation.
class ChannelListItem extends StatefulWidget {
  const ChannelListItem({
    required this.channel,
    this.onTap,
    this.onDoubleTap,
    this.currentProgram,
    this.programProgress,
    this.nextProgramLabel,
    this.onLongPress,
    this.onToggleFavorite,
    this.onFocus,
    this.onHover,
    this.onMiddleClick,
    this.autofocus = false,
    this.isDuplicate = false,
    this.isPlaying = false,
    super.key,
  });

  final Channel channel;
  final VoidCallback? onTap;

  /// Called on double-tap / double-click (e.g. enter fullscreen).
  final VoidCallback? onDoubleTap;

  final String? currentProgram;
  final double? programProgress;

  /// Title + start time of the next programme, shown as a
  /// second subtitle line below the current programme.
  ///
  /// Format: "Next: Title · HH:MM"
  final String? nextProgramLabel;
  final VoidCallback? onLongPress;

  /// Called when the hover star is tapped.
  final VoidCallback? onToggleFavorite;

  /// Called when this item gains keyboard/D-pad focus.
  final VoidCallback? onFocus;

  /// Called when this item is hovered with mouse.
  final VoidCallback? onHover;

  /// Called on middle mouse button click.
  final VoidCallback? onMiddleClick;

  final bool autofocus;

  /// Whether this channel is a duplicate.
  final bool isDuplicate;

  /// Whether this channel is currently playing.
  final bool isPlaying;

  @override
  State<ChannelListItem> createState() => _ChannelListItemState();
}

class _ChannelListItemState extends State<ChannelListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final crispyColors = theme.crispyColors;

    // The AnimatedContainer is the visual content of each row.
    final animatedContainer = AnimatedContainer(
      duration: CrispyAnimation.fast,
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      decoration: BoxDecoration(
        // Intentional flat row — no radius on the container itself.
        borderRadius: BorderRadius.zero,
        color: colorScheme.surfaceContainerLow,
      ),
      child: Row(
        children: [
          _ChannelLogo(
            channelId: channel.id,
            logoUrl: channel.logoUrl,
            channelName: channel.name,
          ),
          const SizedBox(width: CrispySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (channel.number != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CrispySpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(CrispyRadius.xs),
                        ),
                        child: Text(
                          '${channel.number}',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: CrispySpacing.sm),
                    ],
                    if (widget.isPlaying) ...[
                      Icon(
                        Icons.play_arrow,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: CrispySpacing.xxs),
                    ],
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: channel.name,
                              style: textTheme.titleSmall?.copyWith(
                                color:
                                    widget.isPlaying
                                        ? colorScheme.primary
                                        : null,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.currentProgram != null) ...[
                              TextSpan(
                                text: ' — ',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: widget.currentProgram!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (widget.programProgress != null) ...[
                  const SizedBox(height: CrispySpacing.xs),
                  ClipRect(
                    child: LinearProgressIndicator(
                      value: widget.programProgress,
                      minHeight: 3,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        crispyColors.liveRed,
                      ),
                    ),
                  ),
                ],
                if (widget.nextProgramLabel != null) ...[
                  const SizedBox(height: CrispySpacing.xxs),
                  Text(
                    widget.nextProgramLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: CrispySpacing.sm),
          if (channel.resolution != null)
            Container(
              margin: const EdgeInsets.only(right: CrispySpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(CrispyRadius.xs),
              ),
              child: Text(
                channel.resolution!,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Catch-up badge — shown when the channel supports archive
          // playback (hasCatchup == true from M3U/Xtream metadata).
          if (channel.hasCatchup)
            Padding(
              padding: const EdgeInsets.only(right: CrispySpacing.xs),
              child: Tooltip(
                message:
                    channel.catchupDays > 0
                        ? 'Catch-up: ${channel.catchupDays}d'
                        : 'Catch-up available',
                child: Icon(
                  Icons.history,
                  size: 15,
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          if (widget.isDuplicate)
            Container(
              margin: const EdgeInsets.only(right: CrispySpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(CrispyRadius.xs),
              ),
              child: Text(
                'DUP',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Actionable favorite star
          if (widget.onToggleFavorite != null)
            FavoriteStarOverlay(
              isFavorite: channel.isFavorite,
              isHovered: _isHovered,
              onToggle: widget.onToggleFavorite!,
              size: 20,
            )
          else if (channel.isFavorite)
            Icon(Icons.star, size: 20, color: colorScheme.primary),
        ],
      ),
    );

    // When onDoubleTap is provided, wrap the content with a
    // RawGestureDetector using SerialTapGestureRecognizer so that
    // single and double taps can be distinguished. FocusWrapper.onSelect
    // is set to null in that case — tap routing moves to the recognizer.
    final Widget focusChild =
        widget.onDoubleTap != null
            ? RawGestureDetector(
              gestures: {
                SerialTapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      SerialTapGestureRecognizer
                    >(() => SerialTapGestureRecognizer(), (instance) {
                      instance.onSerialTapUp = (details) {
                        if (details.count == 1) widget.onTap?.call();
                        if (details.count == 2) widget.onDoubleTap?.call();
                      };
                    }),
              },
              child: animatedContainer,
            )
            : animatedContainer;

    return Listener(
      onPointerDown: (event) {
        // MIN-01: use bitmask constant for middle mouse button.
        if (event.buttons & kMiddleMouseButton != 0) {
          widget.onMiddleClick?.call();
        }
      },
      child: RepaintBoundary(
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            widget.onHover?.call();
          },
          onExit: (_) => setState(() => _isHovered = false),
          child: FocusWrapper(
            // When onDoubleTap is active, tap routing is handled by the
            // SerialTapGestureRecognizer inside; disable FocusWrapper tap.
            onSelect: widget.onDoubleTap != null ? null : widget.onTap,
            onKeyboardActivate: widget.onDoubleTap,
            onLongPress: widget.onLongPress,
            autofocus: widget.autofocus,
            borderRadius: CrispyRadius.tv,
            scaleFactor: 1.02,
            semanticLabel:
                channel.number != null
                    ? 'Channel ${channel.number}, ${channel.name}'
                    : channel.name,
            onFocusChange: (focused) {
              if (focused) widget.onFocus?.call();
            },
            child: focusChild,
          ),
        ),
      ),
    );
  }
}

/// Channel logo with fallback to first letter.
class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({
    required this.channelId,
    required this.logoUrl,
    required this.channelName,
  });

  final String channelId;
  final String? logoUrl;
  final String channelName;

  @override
  Widget build(BuildContext context) {
    const height = 48.0;
    const width = 85.0; // 16:9 ratio approximately

    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: SmartImage(
          itemId: channelId,
          title: channelName,
          imageUrl: logoUrl,
          imageKind: 'logo',
          fit: BoxFit.contain,
          icon: Icons.live_tv,
          placeholderAspectRatio: width / height,
          memCacheWidth: 170,
        ),
      ),
    );
  }
}
