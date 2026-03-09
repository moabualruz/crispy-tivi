import 'package:flutter/material.dart';

/// Convenience extension on [BuildContext] for showing snackbars.
///
/// Replaces verbose `ScaffoldMessenger.of(context).showSnackBar(...)` calls.
extension SnackBarX on BuildContext {
  /// Shows a simple text [SnackBar] with optional [action].
  void showSnackBar(
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Shows an error-styled [SnackBar].
  void showErrorSnackBar(String message) {
    final colorScheme = Theme.of(this).colorScheme;
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Shows a success-styled [SnackBar].
  void showSuccessSnackBar(String message) {
    final colorScheme = Theme.of(this).colorScheme;
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
