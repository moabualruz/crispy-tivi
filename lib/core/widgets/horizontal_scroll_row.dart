import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_spacing.dart';
import 'nav_arrow.dart';

/// Generic horizontal scroll row with optional header and
/// hover-reveal navigation arrows.
///
/// Type parameter [T] is the item type. The caller provides
/// [itemBuilder] to render each item.
///
/// Used to consolidate repeated carousel patterns across features.
///
/// ```dart
/// HorizontalScrollRow<VodItem>(
///   items: myItems,
///   itemWidth: 160,
///   sectionHeight: 280,
///   headerIcon: Icons.movie,
///   headerTitle: 'Recently Added',
///   itemBuilder: (ctx, item, i) => VodPosterCard(item: item),
/// )
/// ```
class HorizontalScrollRow<T> extends StatefulWidget {
  /// Creates a generic horizontal scroll row.
  const HorizontalScrollRow({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemWidth,
    required this.sectionHeight,
    this.headerIcon,
    this.headerTitle,
    this.showNavArrows = true,
    this.headerTrailing,
    this.padding,
    this.itemSpacing = CrispySpacing.sm,
    this.arrowWidth = 48.0,
    this.arrowIconSize = 32.0,
  });

  /// Items to render in the row.
  final List<T> items;

  /// Builder called for each item.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Width of each item cell.
  final double itemWidth;

  /// Total height of the scrollable section (not including header).
  final double sectionHeight;

  /// Optional icon displayed before [headerTitle].
  final IconData? headerIcon;

  /// Optional header title. If null and [headerIcon] is also null,
  /// no header is rendered.
  final String? headerTitle;

  /// Whether to show left/right navigation arrows on hover/focus.
  final bool showNavArrows;

  /// Optional widget placed at the trailing end of the header row.
  final Widget? headerTrailing;

  /// Padding around the scroll list content.
  final EdgeInsetsGeometry? padding;

  /// Spacing between items.
  final double itemSpacing;

  /// Width of the navigation arrow overlay widgets.
  final double arrowWidth;

  /// Icon size used inside navigation arrow widgets.
  final double arrowIconSize;

  @override
  State<HorizontalScrollRow<T>> createState() => _HorizontalScrollRowState<T>();
}

class _HorizontalScrollRowState<T> extends State<HorizontalScrollRow<T>> {
  final _scrollController = ScrollController();
  bool _isHovered = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.enterCurve,
    );
  }

  bool get _hasHeader =>
      widget.headerTitle != null || widget.headerIcon != null;

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        widget.padding ??
        const EdgeInsets.symmetric(horizontal: CrispySpacing.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasHeader)
          Padding(
            padding: const EdgeInsets.only(
              left: CrispySpacing.md,
              right: CrispySpacing.md,
              top: CrispySpacing.xl,
              bottom: CrispySpacing.xs,
            ),
            child: Row(
              children: [
                if (widget.headerIcon != null) ...[
                  Icon(
                    widget.headerIcon!,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: CrispySpacing.sm),
                ],
                if (widget.headerTitle != null)
                  Expanded(
                    child: Text(
                      widget.headerTitle!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (widget.headerTrailing != null) widget.headerTrailing!,
              ],
            ),
          ),
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: SizedBox(
            height: widget.sectionHeight,
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: effectivePadding,
                  itemCount: widget.items.length,
                  itemBuilder: (ctx, i) {
                    return Padding(
                      padding: EdgeInsets.only(right: widget.itemSpacing),
                      child: SizedBox(
                        width: widget.itemWidth,
                        child: widget.itemBuilder(ctx, widget.items[i], i),
                      ),
                    );
                  },
                ),
                if (widget.showNavArrows && _isHovered)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: widget.arrowWidth,
                    child: NavArrow(
                      icon: Icons.chevron_left,
                      onTap: () => _scrollBy(-(widget.itemWidth * 3)),
                      isLeft: true,
                      iconSize: widget.arrowIconSize,
                    ),
                  ),
                if (widget.showNavArrows && _isHovered)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: widget.arrowWidth,
                    child: NavArrow(
                      icon: Icons.chevron_right,
                      onTap: () => _scrollBy(widget.itemWidth * 3),
                      isLeft: false,
                      iconSize: widget.arrowIconSize,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
