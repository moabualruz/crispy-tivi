import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/entities/channel.dart';
import '../providers/channel_providers.dart';

/// Wraps a channel list item with swipe-to-reveal actions on
/// mobile (compact breakpoint only).
///
/// - **Left swipe** (end-to-start): toggle favorite.
/// - **Right swipe** (start-to-end): hide channel.
///
/// On tablet/TV/desktop (medium and above) this widget passes
/// [child] through unchanged — no swipe handling occurs.
///
/// Implementation uses [Dismissible] with [confirmDismiss] to
/// prevent actual removal. The dismiss gesture reveals the action
/// colour, the callback fires, and the widget snaps back.
class ChannelSwipeActions extends ConsumerStatefulWidget {
  const ChannelSwipeActions({
    super.key,
    required this.channel,
    required this.child,
    this.onHidden,
  });

  final Channel channel;
  final Widget child;

  /// Called after the hide action completes (channel is hidden
  /// in settings). Callers may use this to show a snack-bar.
  final VoidCallback? onHidden;

  @override
  ConsumerState<ChannelSwipeActions> createState() =>
      _ChannelSwipeActionsState();
}

class _ChannelSwipeActionsState extends ConsumerState<ChannelSwipeActions> {
  /// Key used by [Dismissible]. Must be unique per item so
  /// Flutter can differentiate rows during animations.
  late final _dismissKey = TestKeys.swipeChannel(widget.channel.id);

  // ── Favorite toggle (left swipe / end-to-start) ─────────────

  Future<bool?> _onFavoriteSwiped() async {
    await ref
        .read(channelListProvider.notifier)
        .toggleFavorite(widget.channel.id);
    // Return false so the item stays in the list (no dismiss).
    return false;
  }

  // ── Hide channel (right swipe / start-to-end) ───────────────

  Future<bool?> _onHideSwiped() async {
    await ref
        .read(settingsNotifierProvider.notifier)
        .hideChannel(widget.channel.id);

    // Sync hidden IDs into channel list state.
    final hiddenIds =
        ref.read(settingsNotifierProvider).value?.allHiddenChannelIds ??
        {widget.channel.id};
    ref.read(channelListProvider.notifier).setHiddenChannelIds(hiddenIds);

    widget.onHidden?.call();

    // Return true so Dismissible removes the row with an
    // exit animation — giving clear visual feedback.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // On non-compact layouts (tablet, desktop, TV) pass through
    // child without swipe wrapping.
    if (!context.isCompact) {
      return widget.child;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final channel = widget.channel;

    return Dismissible(
      key: _dismissKey,
      // ── Directional thresholds ───────────────────────────────
      // Use a generous threshold (0.35) so accidental swipes are
      // less likely to trigger on a channel list.
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.35,
        DismissDirection.endToStart: 0.35,
      },
      // ── Callbacks ────────────────────────────────────────────
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return _onFavoriteSwiped();
        }
        if (direction == DismissDirection.startToEnd) {
          return _onHideSwiped();
        }
        return false;
      },
      // ── Left-swipe background (favorite) ─────────────────────
      // Revealed when swiping right-to-left (end-to-start).
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: colorScheme.primaryContainer,
        icon: channel.isFavorite ? Icons.star_border : Icons.star,
        label:
            channel.isFavorite
                ? context.l10n.contextMenuRemoveFromFavorites
                : context.l10n.contextMenuAddToFavorites,
        foregroundColor: colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.only(right: CrispySpacing.lg),
      ),
      // ── Right-swipe background (hide) ────────────────────────
      // Revealed when swiping left-to-right (start-to-end).
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: colorScheme.errorContainer,
        icon: Icons.visibility_off,
        label: context.l10n.contextMenuHideChannel,
        foregroundColor: colorScheme.onErrorContainer,
        padding: const EdgeInsets.only(left: CrispySpacing.lg),
      ),
      child: widget.child,
    );
  }
}

/// Coloured action background revealed behind a swipe gesture.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.padding,
  });

  final AlignmentGeometry alignment;
  final Color color;
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foregroundColor, size: 24),
          const SizedBox(width: CrispySpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
