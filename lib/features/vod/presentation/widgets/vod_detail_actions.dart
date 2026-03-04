import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../providers/vod_rating_provider.dart';

/// Circular icon button with label below,
/// used for secondary actions (My List, Rate).
class CircularAction extends StatelessWidget {
  const CircularAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      child: FocusWrapper(
        onSelect: onTap,
        borderRadius: 22.0,
        scaleFactor: 1.08,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outline),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 22),
            ),
            const SizedBox(height: CrispySpacing.xs),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// FE-VODS-05: Thumbs up / down rate action button.
///
/// Cycles through none → thumbs up → thumbs down → none on each tap.
/// Rating is persisted via [vodRatingProvider] (settings key
/// `vod_rating_<itemId>`). Eventually feeds into recommendations.
///
/// Uses [Icons.thumb_up_outlined] / [Icons.thumb_up] and the down
/// equivalents depending on the current [VodRating] state.
class RateAction extends ConsumerWidget {
  const RateAction({super.key, required this.itemId});

  /// The VOD item ID used as the provider key.
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(vodRatingProvider(itemId));
    final VodRating rating = ratingAsync.value ?? VodRating.none;

    final IconData icon;
    final String label;
    switch (rating) {
      case VodRating.up:
        icon = Icons.thumb_up;
        label = 'Liked';
      case VodRating.down:
        icon = Icons.thumb_down;
        label = 'Disliked';
      case VodRating.none:
        icon = Icons.thumb_up_outlined;
        label = 'Rate';
    }

    return CircularAction(
      icon: icon,
      label: label,
      onTap: () => ref.read(vodRatingProvider(itemId).notifier).toggle(),
    );
  }
}

/// Synopsis text with expand/collapse toggle.
class ExpandableSynopsis extends StatefulWidget {
  const ExpandableSynopsis({
    super.key,
    required this.text,
    required this.textTheme,
  });

  final String text;
  final TextTheme textTheme;

  @override
  State<ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<ExpandableSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return FocusWrapper(
      onSelect: () => setState(() => _expanded = !_expanded),
      scaleFactor: 1.0,
      borderRadius: CrispyRadius.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: widget.textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          const SizedBox(height: CrispySpacing.xs),
          Text(
            _expanded ? '...less' : '...more',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
