import 'package:flutter/services.dart';

/// Base class for suppressing stale key-up events after a key category
/// triggers an action (e.g. focus change or route pop).
///
/// While suppressed, all events for the matched key category are consumed;
/// suppression auto-clears on [KeyUpEvent].
///
/// Prevents stale key-up events from firing after actions.
class _KeyUpSuppressor {
  _KeyUpSuppressor(this._keyMatcher);

  final bool Function(LogicalKeyboardKey) _keyMatcher;
  bool _suppressed = false;

  /// Begin suppressing events for this key category.
  void suppress() => _suppressed = true;

  /// Manually clear suppression.
  void clearSuppression() => _suppressed = false;

  /// Returns `true` (consumed) when the event belongs to the matched key
  /// category and suppression is active. Clears suppression on [KeyUpEvent].
  bool consumeIfSuppressed(KeyEvent event) {
    if (!_suppressed) return false;
    if (_keyMatcher(event.logicalKey)) {
      if (event is KeyUpEvent) _suppressed = false;
      return true;
    }
    return false;
  }
}

// ── Key category sets ────────────────────────────────────────

final _selectKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.gameButtonA,
};

final _backKeys = {
  LogicalKeyboardKey.escape,
  LogicalKeyboardKey.backspace,
  LogicalKeyboardKey.goBack,
  LogicalKeyboardKey.browserBack,
  LogicalKeyboardKey.gameButtonB,
};

// ── Public suppressors ───────────────────────────────────────

/// Suppresses the next Select key-up event after a D-pad Select
/// key-down triggers a focus change. Prevents ghost activations
/// on the newly-focused widget.
///
/// Usage:
/// ```dart
/// // In the handler that causes focus change:
/// SelectKeyUpSuppressor.suppressSelectUntilKeyUp();
///
/// // In the key event handler that checks:
/// if (SelectKeyUpSuppressor.consumeIfSuppressed(event)) return;
/// ```
class SelectKeyUpSuppressor {
  static final _instance = _KeyUpSuppressor((k) => _selectKeys.contains(k));

  /// Start suppressing select key-up events.
  static void suppressSelectUntilKeyUp() => _instance.suppress();

  /// Clear any pending suppression.
  static void clearSuppression() => _instance.clearSuppression();

  /// Returns `true` and consumes the event if suppression is active.
  static bool consumeIfSuppressed(KeyEvent event) =>
      _instance.consumeIfSuppressed(event);
}

/// Suppresses the next Back key-up event after a Back key-down
/// pops a route. Prevents double-back on the revealed screen.
///
/// Usage:
/// ```dart
/// // Before popping:
/// BackKeyUpSuppressor.suppressBackUntilKeyUp();
/// Navigator.pop(context);
///
/// // In route-level key handler:
/// if (BackKeyUpSuppressor.consumeIfSuppressed(event)) return;
/// ```
class BackKeyUpSuppressor {
  static final _instance = _KeyUpSuppressor((k) => _backKeys.contains(k));

  /// Start suppressing back key-up events.
  static void suppressBackUntilKeyUp() => _instance.suppress();

  /// Clear any pending suppression.
  static void clearSuppression() => _instance.clearSuppression();

  /// Returns `true` and consumes the event if suppression is active.
  static bool consumeIfSuppressed(KeyEvent event) =>
      _instance.consumeIfSuppressed(event);
}
