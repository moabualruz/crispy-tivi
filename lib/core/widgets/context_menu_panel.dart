import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_spacing.dart';

/// A right-slide context menu panel.
///
/// Slides in from the right edge, overlaying the content area.
/// Organized in sections with optional headers and dividers.
///
/// Usage:
/// ```dart
/// showContextMenuPanel(
///   context: context,
///   sections: [
///     ContextMenuSection(
///       header: 'CNN',
///       headerColor: colorScheme.primary,
///       items: [
///         ContextMenuItem(
///           icon: Icons.star,
///           label: 'Add to Favorites',
///           onTap: () { ... },
///         ),
///       ],
///     ),
///   ],
/// );
/// ```
Future<void> showContextMenuPanel({
  required BuildContext context,
  required List<ContextMenuSection> sections,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close context menu',
    barrierColor: Colors.black38,
    transitionDuration: CrispyAnimation.normal,
    pageBuilder:
        (context, animation, secondaryAnimation) => const SizedBox.shrink(),
    transitionBuilder: (ctx, animation, _, child) {
      final slide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: CrispyAnimation.enterCurve,
          reverseCurve: CrispyAnimation.exitCurve,
        ),
      );

      return Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: slide,
          child: _ContextMenuPanelContent(sections: sections),
        ),
      );
    },
  );
}

/// A section in the context menu panel.
class ContextMenuSection {
  const ContextMenuSection({
    this.header,
    this.headerColor,
    this.items = const [],
  });

  /// Optional header text (e.g., channel/program name).
  final String? header;

  /// Color for header text (default: primary/cyan).
  final Color? headerColor;

  /// Menu items in this section.
  final List<ContextMenuItem> items;
}

/// A single item in the context menu.
class ContextMenuItem {
  const ContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// If true, uses error color for the item.
  final bool isDestructive;
}

class _ContextMenuPanelContent extends StatelessWidget {
  const _ContextMenuPanelContent({required this.sections});

  final List<ContextMenuSection> sections;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      child: SizedBox(
        width: 300,
        height: MediaQuery.sizeOf(context).height,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: CrispySpacing.md),
            children: [
              for (int i = 0; i < sections.length; i++) ...[
                if (i > 0)
                  Divider(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    height: CrispySpacing.md,
                    indent: CrispySpacing.md,
                    endIndent: CrispySpacing.md,
                  ),
                _buildSection(sections[i], colorScheme, textTheme, context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    ContextMenuSection section,
    ColorScheme colorScheme,
    TextTheme textTheme,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (section.header != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.md,
              vertical: CrispySpacing.xs,
            ),
            child: Text(
              section.header!,
              style: textTheme.titleSmall?.copyWith(
                color: section.headerColor ?? colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ...section.items.map(
          (item) => _buildItem(item, colorScheme, textTheme, context),
        ),
      ],
    );
  }

  Widget _buildItem(
    ContextMenuItem item,
    ColorScheme colorScheme,
    TextTheme textTheme,
    BuildContext context,
  ) {
    final color =
        item.isDestructive ? colorScheme.error : colorScheme.onSurface;
    final iconColor =
        item.isDestructive ? colorScheme.error : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          item.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.sm,
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: iconColor),
              const SizedBox(width: CrispySpacing.md),
              Expanded(
                child: Text(
                  item.label,
                  style: textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
