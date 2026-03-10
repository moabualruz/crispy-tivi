import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/crispy_spacing.dart';
import '../utils/device_form_factor.dart';

/// A single action item in a [LongPressMenu].
class LongPressMenuItem {
  /// Creates a long-press menu item.
  const LongPressMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// Leading icon displayed before [label].
  final IconData icon;

  /// Human-readable action label.
  final String label;

  /// Called when the user taps this item.
  final VoidCallback onTap;
}

/// Wraps [child] with a long-press context menu on mobile form factors.
///
/// On desktop and TV the [child] is returned unchanged — these form
/// factors use hover/D-pad menus rather than long-press gestures.
///
/// When the user long-presses on a phone or tablet, [HapticFeedback]
/// fires, and a [PopupMenu] appears at the press location. Selecting
/// an item calls its [LongPressMenuItem.onTap] callback.
///
/// ```dart
/// LongPressMenu(
///   menuItems: [
///     LongPressMenuItem(
///       icon: Icons.favorite,
///       label: 'Add to favourites',
///       onTap: () => ref.read(favoritesProvider.notifier).toggle(item.id),
///     ),
///     LongPressMenuItem(
///       icon: Icons.info_outline,
///       label: 'View details',
///       onTap: () => context.push('/vod/${item.id}'),
///     ),
///   ],
///   child: VodCard(item: item),
/// )
/// ```
class LongPressMenu extends StatelessWidget {
  /// Creates a long-press menu wrapper.
  const LongPressMenu({
    super.key,
    required this.child,
    required this.menuItems,
  });

  /// The content to wrap.
  final Widget child;

  /// Items to display in the pop-up menu. Must not be empty.
  final List<LongPressMenuItem> menuItems;

  @override
  Widget build(BuildContext context) {
    // Long-press menus are only meaningful on touch devices.
    if (!DeviceFormFactorService.current.isMobile || menuItems.isEmpty) {
      return child;
    }

    return GestureDetector(
      onLongPressStart: (details) => _showMenu(context, details.globalPosition),
      child: child,
    );
  }

  Future<void> _showMenu(BuildContext context, Offset position) async {
    HapticFeedback.mediumImpact();

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final relativePosition = RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<LongPressMenuItem>(
      context: context,
      position: relativePosition,
      items:
          menuItems
              .map(
                (item) => PopupMenuItem<LongPressMenuItem>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(item.icon, size: 20),
                      SizedBox(width: CrispySpacing.sm),
                      Text(item.label),
                    ],
                  ),
                ),
              )
              .toList(),
    );

    selected?.onTap();
  }
}
