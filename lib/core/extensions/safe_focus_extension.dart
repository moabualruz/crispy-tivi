import 'package:flutter/widgets.dart';

/// Extension on [FocusNode] for null-safe focus operations.
///
/// Prevents crashes when requesting focus on disposed or detached
/// nodes. Use [requestFocusSafely] instead of [FocusNode.requestFocus]
/// in all focus management code.
extension SafeFocusExtension on FocusNode {
  /// Requests focus on this node if it is attached and able to
  /// accept focus.
  ///
  /// Returns `true` if focus was successfully requested, `false`
  /// if the node is disposed, detached, or cannot accept focus.
  ///
  /// Unlike [requestFocus], this method never throws.
  bool requestFocusSafely() {
    try {
      if (context == null || !canRequestFocus) {
        return false;
      }
      requestFocus();
      return true;
    } catch (_) {
      // Node was disposed or detached — silently fail.
      return false;
    }
  }
}
