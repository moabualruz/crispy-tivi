import 'package:flutter/material.dart';

import '../../domain/entities/vod_item.dart';

/// Shared inherited scope for TV-side VOD item selection.
///
/// Descendants can use this to open a side detail pane instead of
/// immediately navigating to a full details route.
class VodSelectionScope extends InheritedWidget {
  const VodSelectionScope({
    required this.onItemSelected,
    required super.child,
    super.key,
  });

  final ValueChanged<VodItem> onItemSelected;

  static VodSelectionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<VodSelectionScope>();
  }

  @override
  bool updateShouldNotify(VodSelectionScope oldWidget) =>
      onItemSelected != oldWidget.onItemSelected;
}
