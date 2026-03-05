import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/responsive_layout.dart';

/// Responsive list/grid switcher for favorites-style item lists.
///
/// On compact screens renders a single-column [ListView]; on large
/// screens renders a two-column [GridView] using the same item builder
/// and the standard favorites aspect ratio (4.5).
///
/// Type parameter [T] is the item model type.  The caller provides
/// [itemBuilder] to turn each item into a widget — no knowledge of
/// the item type leaks into this widget.
///
/// Used by [ContinueWatchingTab] and [RecentlyWatchedTab] (and any
/// future favorites sub-tab that needs the same pattern).
class FavoritesList<T> extends StatelessWidget {
  const FavoritesList({
    super.key,
    required this.items,
    required this.itemBuilder,
  });

  /// The list of items to display.
  final List<T> items;

  /// Builds the widget for a single [item].
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Cross-axis count used on large (≥ 840 dp) screens.
  static const int _largeColumnCount = 2;

  /// Shared aspect ratio for the grid delegate.
  static const double _childAspectRatio = 4.5;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      compactBody: _buildList(context, crossAxisCount: 1),
      largeBody: _buildList(context, crossAxisCount: _largeColumnCount),
    );
  }

  Widget _buildList(BuildContext context, {required int crossAxisCount}) {
    if (crossAxisCount == 1) {
      return ListView.builder(
        padding: const EdgeInsets.all(CrispySpacing.md),
        itemCount: items.length,
        itemBuilder: (ctx, index) => itemBuilder(ctx, items[index]),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(CrispySpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _largeColumnCount,
        crossAxisSpacing: CrispySpacing.sm,
        mainAxisSpacing: CrispySpacing.sm,
        childAspectRatio: _childAspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) => itemBuilder(ctx, items[index]),
    );
  }
}
