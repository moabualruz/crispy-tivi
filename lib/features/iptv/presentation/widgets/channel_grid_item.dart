import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/theme/crispy_typography.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../domain/entities/channel.dart';

/// A grid tile for a single channel in grid view mode.
///
/// Shows the channel logo centered, with the channel name and
/// optional now-playing text below. Used by [ChannelGridSliver].
///
/// Spec: FE-TV-07.
class ChannelGridItem extends StatefulWidget {
  const ChannelGridItem({
    super.key,
    required this.channel,
    required this.onTap,
    this.currentProgram,
    this.isPlaying = false,
    this.autofocus = false,
  });

  final Channel channel;
  final VoidCallback onTap;

  /// Now-playing programme title from EPG.
  final String? currentProgram;

  /// Whether this channel is currently playing.
  final bool isPlaying;

  final bool autofocus;

  @override
  State<ChannelGridItem> createState() => _ChannelGridItemState();
}

class _ChannelGridItemState extends State<ChannelGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: FocusWrapper(
        focusStyle: FocusIndicatorStyle.card,
        onSelect: widget.onTap,
        autofocus: widget.autofocus,
        borderRadius: CrispyRadius.tv,
        scaleFactor: 1.04,
        semanticLabel:
            widget.channel.number != null
                ? 'Channel ${widget.channel.number}, ${widget.channel.name}'
                : widget.channel.name,
        child: AnimatedContainer(
          duration: CrispyAnimation.fast,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
            color:
                widget.isPlaying || _isHovered
                    ? cs.primaryContainer.withValues(alpha: 0.4)
                    : cs.surfaceContainerLow,
            border: Border.all(
              color:
                  widget.isPlaying
                      ? cs.primary
                      : cs.outlineVariant.withValues(alpha: 0.3),
              width: widget.isPlaying ? 1.5 : 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.sm,
              vertical: CrispySpacing.sm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Expanded(
                  child: Center(
                    child: ClipRect(
                      child: SmartImage(
                        itemId: widget.channel.id,
                        title: widget.channel.name,
                        imageUrl: widget.channel.logoUrl,
                        imageKind: 'logo',
                        fit: BoxFit.contain,
                        icon: Icons.live_tv,
                        placeholderAspectRatio: 1.6,
                        memCacheWidth: 160,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: CrispySpacing.xs),
                // Channel name
                Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: widget.isPlaying ? cs.primary : cs.onSurface,
                  ),
                ),
                // Now-playing label (optional)
                if (widget.currentProgram != null) ...[
                  const SizedBox(height: CrispySpacing.xxs),
                  Text(
                    widget.currentProgram!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: tt.labelSmall?.copyWith(
                      fontSize: CrispyTypography.micro,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
