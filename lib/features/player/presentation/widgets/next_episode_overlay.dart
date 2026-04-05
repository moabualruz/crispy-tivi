import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../../vod/domain/utils/episode_utils.dart' show formatEpisodeLabel;
import 'player_osd/osd_shared.dart';

/// Overlay shown when an episode is near completion.
/// Auto-advances after countdown unless dismissed.
///
/// Cinematic design: thumbnail preview, animated
/// countdown progress bar, season/episode badge.
class NextEpisodeOverlay extends StatefulWidget {
  const NextEpisodeOverlay({
    required this.nextEpisode,
    required this.onPlayNext,
    required this.onCancel,
    this.autoplayEnabled = true,
    this.countdownSeconds = 10,
    super.key,
  });

  final VodItem nextEpisode;
  final VoidCallback onPlayNext;
  final VoidCallback onCancel;
  final bool autoplayEnabled;
  final int countdownSeconds;

  @override
  State<NextEpisodeOverlay> createState() => _NextEpisodeOverlayState();
}

class _NextEpisodeOverlayState extends State<NextEpisodeOverlay>
    with SingleTickerProviderStateMixin {
  late int _secondsRemaining;
  AnimationController? _progressController;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.countdownSeconds;
    if (widget.autoplayEnabled) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.countdownSeconds),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onPlayNext();
        }
      });

      // Tick display counter every second.
      controller.addListener(() {
        final remaining =
            (widget.countdownSeconds * (1.0 - controller.value)).ceil();
        if (remaining != _secondsRemaining) {
          setState(() => _secondsRemaining = remaining);
        }
      });

      controller.forward();
      _progressController = controller;
    }
  }

  @override
  void dispose() {
    _progressController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.nextEpisode;
    final colorScheme = Theme.of(context).colorScheme;

    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      right: CrispySpacing.lg,
      bottom: safeBottom + kOsdBottomBarHeight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(CrispySpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(CrispyRadius.md),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with countdown
              Row(
                children: [
                  Icon(Icons.skip_next, color: colorScheme.primary, size: 20),
                  const SizedBox(width: CrispySpacing.sm),
                  Text(
                    widget.autoplayEnabled
                        ? context.l10n.playerNextUpIn(_secondsRemaining)
                        : 'Up Next',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              if (widget.autoplayEnabled) ...[
                const SizedBox(height: CrispySpacing.sm),

                // Animated countdown progress bar
                AnimatedBuilder(
                  animation: _progressController!,
                  builder:
                      (context, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(
                          CrispyRadius.progressBar,
                        ),
                        child: LinearProgressIndicator(
                          value: 1.0 - _progressController!.value,
                          minHeight: 3,
                          backgroundColor: colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                          color: colorScheme.primary,
                        ),
                      ),
                ),
              ],
              const SizedBox(height: CrispySpacing.sm),

              // Thumbnail + episode info row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail (16:9 aspect, if available)
                  if (ep.posterUrl != null && ep.posterUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: CrispySpacing.sm),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(CrispyRadius.md),
                        child: SizedBox(
                          width: 80,
                          height: 45,
                          child: SmartImage(
                            itemId: ep.id,
                            title: ep.name,
                            imageUrl: ep.posterUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                  // Title + season/episode
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ep.name,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ep.seasonNumber != null && ep.episodeNumber != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: CrispySpacing.xs,
                            ),
                            child: Text(
                              formatEpisodeLabel(
                                ep.seasonNumber,
                                ep.episodeNumber,
                              ),
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CrispySpacing.md),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                        side: BorderSide(
                          color: colorScheme.onSurface.withValues(alpha: 0.54),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: CrispySpacing.md,
                        ),
                      ),
                      child: Text(context.l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: CrispySpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onPlayNext,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: CrispySpacing.md,
                        ),
                      ),
                      child: Text(context.l10n.playerPlayNow),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
