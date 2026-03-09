import 'package:flutter/material.dart';

/// A [FocusTraversalPolicy] that maintains logical row/col position
/// when navigating a grid with D-pad arrows.
///
/// Without this policy, Flutter's default traversal often jumps to
/// the wrong column when moving up/down in a grid because it picks
/// the geometrically closest focusable node, which can shift columns
/// on rows with varying item widths.
///
/// Maintains column position when traversing a grid with D-pad.
class GridFocusTravelerPolicy extends WidgetOrderTraversalPolicy {
  GridFocusTravelerPolicy({required this.crossAxisCount, this.onChanged});

  /// Number of columns in the grid.
  final int crossAxisCount;

  /// Called with the new flat index when focus changes.
  final ValueChanged<int>? onChanged;

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final parent = currentNode.parent;
    if (parent == null) {
      return super.inDirection(currentNode, direction);
    }

    final nodes = _childNodes(parent);
    final current = nodes.indexOf(currentNode);
    if (current == -1) {
      return super.inDirection(currentNode, direction);
    }

    final itemCount = nodes.length;
    final row = current ~/ crossAxisCount;
    final col = current % crossAxisCount;
    final rowCount = (itemCount / crossAxisCount).ceil();

    int? next;
    switch (direction) {
      case TraversalDirection.left:
        if (col > 0) next = current - 1;
      case TraversalDirection.right:
        if (col < crossAxisCount - 1 && current + 1 < itemCount) {
          next = current + 1;
        }
      case TraversalDirection.up:
        if (row > 0) next = current - crossAxisCount;
      case TraversalDirection.down:
        if (row < rowCount - 1) {
          final candidate = current + crossAxisCount;
          if (candidate < itemCount) next = candidate;
        }
    }

    if (next != null) {
      nodes[next].requestFocus();
      onChanged?.call(next);
      return true;
    }

    // Let the parent traversal group handle edge cases (e.g.
    // moving left from col 0 to a sidebar).
    return super.inDirection(currentNode, direction);
  }
}

/// Returns focusable child nodes sorted by visual position
/// (top-to-bottom, left-to-right).
List<FocusNode> _childNodes(FocusNode node) {
  return node.descendants
      .where((n) => n.canRequestFocus && n.context != null)
      .toList()
    ..sort((a, b) {
      final dy = a.rect.top.compareTo(b.rect.top);
      return dy != 0 ? dy : a.rect.left.compareTo(b.rect.left);
    });
}

/// Convenience widget that wraps its [child] in a [FocusTraversalGroup]
/// with [GridFocusTravelerPolicy].
///
/// Usage:
/// ```dart
/// GridFocusTraveler(
///   crossAxisCount: 3,
///   child: GridView.builder(...),
/// )
/// ```
class GridFocusTraveler extends StatelessWidget {
  const GridFocusTraveler({
    required this.crossAxisCount,
    required this.child,
    this.onChanged,
    super.key,
  });

  /// Number of columns in the grid.
  final int crossAxisCount;

  /// The grid widget to wrap.
  final Widget child;

  /// Called with the new flat index when focus changes.
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: GridFocusTravelerPolicy(
        crossAxisCount: crossAxisCount,
        onChanged: onChanged,
      ),
      child: child,
    );
  }
}
