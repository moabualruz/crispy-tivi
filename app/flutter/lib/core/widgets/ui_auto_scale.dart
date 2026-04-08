import 'package:flutter/widgets.dart';

/// Provides the computed UI auto-scale factor to descendants.
///
/// Inserted at the root by [CrispyTiviApp] when the physical
/// screen height is ≥ 1440 px. Used by [ResponsiveLayout] to
/// evaluate breakpoints against the original (unscaled) logical
/// width.
class UiAutoScale extends InheritedWidget {
  const UiAutoScale({required this.scale, required super.child, super.key});

  /// The auto-scale factor (1.0 = no scaling).
  final double scale;

  /// Returns the current auto-scale factor, or 1.0 if none.
  static double of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UiAutoScale>()?.scale ??
        1.0;
  }

  @override
  bool updateShouldNotify(UiAutoScale oldWidget) => oldWidget.scale != scale;
}
