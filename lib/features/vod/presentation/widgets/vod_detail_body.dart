import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/entities/vod_item.dart';
import '../../../../core/utils/date_format_utils.dart' show formatRuntime;
import 'vod_detail_actions.dart'
    show CircularAction, ExpandableSynopsis, RateAction;

/// Width of the label column in [MetaRow].
const _kMetaLabelWidth = 80.0;

/// Height of the primary play button.
const _kPlayButtonHeight = 48.0;

/// Wraps synopsis + actions with a responsive
/// two-column layout on desktop (>= 1280px).
class BodyContent extends StatelessWidget {
  const BodyContent({
    super.key,
    required this.item,
    required this.liveItem,
    required this.textTheme,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.isWatched,
    required this.onMarkWatched,
    required this.onShare,
  });

  final VodItem item;
  final VodItem liveItem;
  final TextTheme textTheme;

  /// Null while the play action is loading (button shows spinner + disabled).
  final VoidCallback? onPlay;
  final VoidCallback onToggleFavorite;

  /// FE-VD-09: Whether this item is marked as watched (>= 95% progress).
  final bool isWatched;

  /// FE-VD-09: Callback to toggle the watched state.
  final VoidCallback onMarkWatched;

  /// FE-VD-10: Callback to copy title+year to clipboard.
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= Breakpoints.large;

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column (60%): actions + synopsis
            Expanded(flex: 3, child: _leftColumn(context)),
            const SizedBox(width: CrispySpacing.xl),
            // Right column (40%): cast, genres, meta
            Expanded(flex: 2, child: _rightColumn()),
          ],
        ),
      );
    }

    // Mobile / tablet: single column
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _actionsBlock(context),
          const SizedBox(height: CrispySpacing.xl),
          if (item.description != null && item.description!.isNotEmpty)
            ExpandableSynopsis(text: item.description!, textTheme: textTheme),
          // Metadata below synopsis on mobile
          if (_hasMetadata()) ...[
            const SizedBox(height: CrispySpacing.lg),
            _metadataColumn(),
          ],
          const SizedBox(height: CrispySpacing.xxl),
        ],
      ),
    );
  }

  Widget _leftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _actionsBlock(context),
        const SizedBox(height: CrispySpacing.xl),
        if (item.description != null && item.description!.isNotEmpty)
          ExpandableSynopsis(text: item.description!, textTheme: textTheme),
        const SizedBox(height: CrispySpacing.xxl),
      ],
    );
  }

  Widget _rightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CrispySpacing.md),
        _metadataColumn(),
        const SizedBox(height: CrispySpacing.xxl),
      ],
    );
  }

  Widget _actionsBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Netflix-style Play button
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: _kPlayButtonHeight,
                child: FocusWrapper(
                  onSelect: onPlay ?? () {},
                  borderRadius: CrispyRadius.xs,
                  child: FilledButton.icon(
                    onPressed: onPlay,
                    icon:
                        onPlay == null
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Icon(
                              Icons.play_arrow_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                    label: Text(
                      onPlay == null ? 'Loading…' : 'Play',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(CrispyRadius.tv),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CrispySpacing.sm),
        // Secondary actions row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularAction(
              icon: liveItem.isFavorite ? Icons.check : Icons.add,
              label: 'My List',
              onTap: onToggleFavorite,
            ),
            const SizedBox(width: CrispySpacing.xl),
            // FE-VD-09: Mark as Watched / Unwatched toggle
            CircularAction(
              icon: isWatched ? Icons.check_circle : Icons.check_circle_outline,
              label: isWatched ? 'Watched' : 'Mark Watched',
              onTap: onMarkWatched,
            ),
            const SizedBox(width: CrispySpacing.xl),
            // FE-VODS-05: Thumbs up / down rating
            RateAction(itemId: item.id),
            const SizedBox(width: CrispySpacing.xl),
            // FE-VD-10: Share — copies title+year to clipboard
            CircularAction(
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: onShare,
            ),
          ],
        ),
      ],
    );
  }

  Widget _metadataColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.category != null && item.category!.isNotEmpty) ...[
          MetaRow(label: 'Genre', value: item.category!, textTheme: textTheme),
          const SizedBox(height: CrispySpacing.md),
        ],
        if (item.year != null) ...[
          MetaRow(label: 'Year', value: '${item.year}', textTheme: textTheme),
          const SizedBox(height: CrispySpacing.md),
        ],
        if (item.rating != null && item.rating!.isNotEmpty) ...[
          MetaRow(label: 'Rating', value: item.rating!, textTheme: textTheme),
          const SizedBox(height: CrispySpacing.md),
        ],
        // FE-VD-03: Runtime formatted as "Xh Ym" (e.g. "1h 52m", "45m")
        if (item.duration != null) ...[
          MetaRow(
            label: 'Duration',
            value: formatRuntime(item.duration!),
            textTheme: textTheme,
          ),
          const SizedBox(height: CrispySpacing.md),
        ],
        if (item.director != null && item.director!.isNotEmpty) ...[
          MetaRow(
            label: 'Director',
            value: item.director!,
            textTheme: textTheme,
          ),
          const SizedBox(height: CrispySpacing.md),
        ],
        if (item.extension != null && item.extension!.isNotEmpty) ...[
          MetaRow(
            label: 'Format',
            value: item.extension!.toUpperCase(),
            textTheme: textTheme,
          ),
          const SizedBox(height: CrispySpacing.md),
        ],
      ],
    );
  }

  bool _hasMetadata() {
    return item.category != null ||
        item.year != null ||
        item.rating != null ||
        item.duration != null ||
        (item.extension != null && item.extension!.isNotEmpty);
  }
}

/// Key-value row for the metadata column.
class MetaRow extends StatelessWidget {
  const MetaRow({
    super.key,
    required this.label,
    required this.value,
    required this.textTheme,
  });

  final String label;
  final String value;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _kMetaLabelWidth,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
