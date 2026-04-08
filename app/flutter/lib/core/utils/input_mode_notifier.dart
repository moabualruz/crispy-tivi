import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/input_mode_scope.dart';

/// The detected user input method.
enum InputMode {
  /// Mouse / trackpad.
  mouse,

  /// Physical keyboard or remote control.
  keyboard,

  /// Gamepad / game controller.
  gamepad,

  /// Touch screen.
  touch,
}

/// Riverpod provider for the current [InputMode].
///
/// Reads from [InputModeNotifier] which auto-detects
/// the active input method based on pointer and key events.
final inputModeProvider = NotifierProvider<InputModeNotifier, InputMode>(
  InputModeNotifier.new,
);

/// Tracks the user's current input method and updates
/// automatically based on pointer moves, key presses,
/// gamepad buttons, and touch events.
///
/// Focus rings are shown only for [InputMode.keyboard]
/// and [InputMode.gamepad]; hidden for mouse and touch.
class InputModeNotifier extends Notifier<InputMode> {
  @override
  InputMode build() => InputMode.mouse;

  /// Call when a pointer event is detected.
  void onPointerEvent(PointerEvent event) {
    if (event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus) {
      _setMode(InputMode.touch);
    } else if (event.kind == PointerDeviceKind.mouse ||
        event.kind == PointerDeviceKind.trackpad) {
      // Only switch to mouse on movement, not clicks
      // (clicks during keyboard mode stay keyboard).
      if (event is PointerHoverEvent || event is PointerMoveEvent) {
        _setMode(InputMode.mouse);
      }
    }
  }

  /// Call when a raw key event is detected.
  void onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return;
    }
    if (_isGamepadButton(event.logicalKey)) {
      _setMode(InputMode.gamepad);
    } else {
      _setMode(InputMode.keyboard);
    }
  }

  void _setMode(InputMode mode) {
    if (state != mode) {
      state = mode;
    }
  }

  /// Whether the current mode should show focus rings.
  static bool showFocusIndicators(InputMode mode) =>
      mode == InputMode.keyboard || mode == InputMode.gamepad;

  /// Gamepad buttons reported as logical keys.
  static bool _isGamepadButton(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.gameButtonX ||
        key == LogicalKeyboardKey.gameButtonY ||
        key == LogicalKeyboardKey.gameButtonLeft1 ||
        key == LogicalKeyboardKey.gameButtonLeft2 ||
        key == LogicalKeyboardKey.gameButtonRight1 ||
        key == LogicalKeyboardKey.gameButtonRight2 ||
        key == LogicalKeyboardKey.gameButtonStart ||
        key == LogicalKeyboardKey.gameButtonSelect ||
        key == LogicalKeyboardKey.gameButtonMode ||
        key == LogicalKeyboardKey.gameButtonThumbLeft ||
        key == LogicalKeyboardKey.gameButtonThumbRight;
  }
}

/// Widget that sits at the top of the widget tree and
/// listens for pointer / key events to auto-detect the
/// user's input method.
///
/// Place above [MaterialApp] in the widget tree:
/// ```dart
/// InputModeDetector(
///   child: MaterialApp.router( ... ),
/// )
/// ```
class InputModeDetector extends ConsumerStatefulWidget {
  /// Creates an input mode detector.
  const InputModeDetector({required this.child, super.key});

  /// The subtree to wrap.
  final Widget child;

  @override
  ConsumerState<InputModeDetector> createState() => _InputModeDetectorState();
}

class _InputModeDetectorState extends ConsumerState<InputModeDetector> {
  @override
  void initState() {
    super.initState();
    // Use HardwareKeyboard to receive ALL key events globally,
    // regardless of focus tree handling. KeyboardListener only
    // sees events that bubble up unhandled — but arrow keys,
    // Enter, Escape, etc. are consumed by focus traversal /
    // CallbackShortcuts before reaching the root, so the mode
    // would never switch from mouse to keyboard.
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  /// Forwards hardware key events to the input mode notifier.
  ///
  /// Returns `false` so the event continues through the normal
  /// focus system — we only observe, never consume.
  bool _onHardwareKey(KeyEvent event) {
    ref.read(inputModeProvider.notifier).onKeyEvent(event);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Single watch for the entire tree — all descendants
    // read via InputModeScope.of(context) instead of
    // per-instance ref.watch(inputModeProvider).
    final inputMode = ref.watch(inputModeProvider);
    final showFocus = InputModeNotifier.showFocusIndicators(inputMode);

    return Listener(
      onPointerHover:
          (event) => ref.read(inputModeProvider.notifier).onPointerEvent(event),
      onPointerMove:
          (event) => ref.read(inputModeProvider.notifier).onPointerEvent(event),
      onPointerDown:
          (event) => ref.read(inputModeProvider.notifier).onPointerEvent(event),
      behavior: HitTestBehavior.translucent,
      child: InputModeScope(
        showFocusIndicators: showFocus,
        child: widget.child,
      ),
    );
  }
}
