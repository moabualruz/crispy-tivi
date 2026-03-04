import 'package:flutter/widgets.dart';

/// InheritedWidget that provides input mode state to the
/// widget tree without per-instance provider watches.
///
/// Place a single [InputModeScope] near the root of the
/// widget tree (e.g. inside [InputModeDetector]) so that
/// all [FocusWrapper] instances read the value via
/// [InputModeScope.of] instead of each watching the
/// Riverpod provider individually.
///
/// This reduces 500+ `ref.watch(inputModeProvider)` calls
/// down to a single watch + O(1) InheritedWidget lookups.
class InputModeScope extends InheritedWidget {
  /// Creates an [InputModeScope].
  const InputModeScope({
    required this.showFocusIndicators,
    required super.child,
    super.key,
  });

  /// Whether focus indicators (border ring, scale) should
  /// be visible. `true` for keyboard/gamepad modes, `false`
  /// for mouse/touch.
  final bool showFocusIndicators;

  /// Returns [showFocusIndicators] from the nearest
  /// ancestor [InputModeScope].
  ///
  /// Falls back to `false` (mouse mode) if no scope is
  /// found — safe default that hides focus rings.
  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<InputModeScope>();
    return scope?.showFocusIndicators ?? false;
  }

  @override
  bool updateShouldNotify(InputModeScope oldWidget) =>
      showFocusIndicators != oldWidget.showFocusIndicators;
}
