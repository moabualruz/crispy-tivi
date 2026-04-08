import 'package:flutter/material.dart';

/// Persistent header delegate that pins the series detail [TabBar]
/// to the top of the [NestedScrollView] body.
class SeriesTabBarDelegate extends SliverPersistentHeaderDelegate {
  const SeriesTabBarDelegate(this.tabBar);

  /// The tab bar to display as a pinned header.
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(SeriesTabBarDelegate oldDelegate) => false;
}
