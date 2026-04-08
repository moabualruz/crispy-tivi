import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tv_color_button_legend.dart';

/// Keyboard/remote handler that dispatches F1-F4 keys to [TvColorButton] actions.
///
/// Wraps a child widget and intercepts key events, mapping:
/// - F1 -> [TvColorButton.red]
/// - F2 -> [TvColorButton.green]
/// - F3 -> [TvColorButton.yellow]
/// - F4 -> [TvColorButton.blue]
///
/// ```dart
/// TvColorButtonHandler(
///   colorButtonMap: colorButtons,
///   child: MyScreenContent(),
/// )
/// ```
class TvColorButtonHandler extends StatelessWidget {
  /// Creates a TV color button key handler.
  const TvColorButtonHandler({
    required this.colorButtonMap,
    required this.child,
    super.key,
  });

  /// Map of color buttons to their actions.
  final Map<TvColorButton, ColorButtonAction> colorButtonMap;

  /// The child widget tree.
  final Widget child;

  static final _keyMap = {
    LogicalKeyboardKey.f1: TvColorButton.red,
    LogicalKeyboardKey.f2: TvColorButton.green,
    LogicalKeyboardKey.f3: TvColorButton.yellow,
    LogicalKeyboardKey.f4: TvColorButton.blue,
  };

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final colorButton = _keyMap[event.logicalKey];
    if (colorButton == null) return KeyEventResult.ignored;

    final action = colorButtonMap[colorButton];
    if (action == null) return KeyEventResult.ignored;

    action.onPressed();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(onKeyEvent: _handleKey, child: child);
  }
}
