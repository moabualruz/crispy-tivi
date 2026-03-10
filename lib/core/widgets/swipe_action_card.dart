import 'package:flutter/material.dart';

import '../theme/crispy_spacing.dart';
import '../utils/device_form_factor.dart';

/// A card that reveals swipe actions on mobile form factors.
///
/// On desktop and TV, the [child] is returned as-is — swipe actions
/// are inappropriate for pointer/D-pad input. On phones and tablets
/// a [Dismissible] shell reveals coloured action backgrounds when the
/// user swipes, but the dismiss is always cancelled so the item stays
/// in the list. [onSwipeLeft] / [onSwipeRight] are invoked instead.
///
/// ```dart
/// SwipeActionCard(
///   itemKey: ValueKey(channel.id),
///   onSwipeRight: () => ref.read(favoritesProvider.notifier).toggle(channel.id),
///   onSwipeLeft: () => ref.read(historyProvider.notifier).remove(channel.id),
///   child: ChannelListTile(channel: channel),
/// )
/// ```
class SwipeActionCard extends StatelessWidget {
  /// Creates a swipe-action card.
  const SwipeActionCard({
    super.key,
    required this.child,
    required this.itemKey,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.leftIcon = Icons.favorite,
    this.leftLabel = 'Favorite',
    this.rightIcon = Icons.delete,
    this.rightLabel = 'Remove',
    this.leftColor,
    this.rightColor,
  });

  /// The content to display inside the card.
  final Widget child;

  /// Unique key forwarded to [Dismissible] to identify this item in the list.
  final Key itemKey;

  /// Called when the user swipes from right to left (end → start).
  final VoidCallback? onSwipeLeft;

  /// Called when the user swipes from left to right (start → end).
  final VoidCallback? onSwipeRight;

  /// Icon shown in the left (start → end) action background.
  final IconData leftIcon;

  /// Label shown in the left (start → end) action background.
  final String leftLabel;

  /// Icon shown in the right (end → start) action background.
  final IconData rightIcon;

  /// Label shown in the right (end → start) action background.
  final String rightLabel;

  /// Background colour for the left swipe action.
  ///
  /// Defaults to [ColorScheme.primary] when null.
  final Color? leftColor;

  /// Background colour for the right swipe action.
  ///
  /// Defaults to [ColorScheme.error] when null.
  final Color? rightColor;

  @override
  Widget build(BuildContext context) {
    // Swipe actions are not applicable on desktop or TV.
    if (!DeviceFormFactorService.current.isMobile) {
      return child;
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: itemKey,
      // Always cancel the actual dismiss — we only want the action callback.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onSwipeRight?.call();
        } else {
          onSwipeLeft?.call();
        }
        return false;
      },
      background: _buildBackground(
        context,
        alignment: Alignment.centerLeft,
        color: leftColor ?? colorScheme.primary,
        icon: leftIcon,
        label: leftLabel,
      ),
      secondaryBackground: _buildBackground(
        context,
        alignment: Alignment.centerRight,
        color: rightColor ?? colorScheme.error,
        icon: rightIcon,
        label: rightLabel,
      ),
      child: child,
    );
  }

  Widget _buildBackground(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      color: color,
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            isLeft
                ? [
                  Icon(icon, color: Colors.white),
                  SizedBox(width: CrispySpacing.sm),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]
                : [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: CrispySpacing.sm),
                  Icon(icon, color: Colors.white),
                ],
      ),
    );
  }
}
