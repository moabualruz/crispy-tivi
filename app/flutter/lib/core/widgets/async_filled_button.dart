import 'package:flutter/material.dart';

/// A [FilledButton] that shows a loading spinner when [isLoading] is true.
///
/// While loading, the button is disabled (`onPressed` is set to `null`)
/// and the child is replaced with a fixed 20×20 [CircularProgressIndicator].
///
/// Usage:
/// ```dart
/// AsyncFilledButton(
///   isLoading: _isVerifying,
///   label: 'Add',
///   onPressed: _submit,
/// )
/// ```
class AsyncFilledButton extends StatelessWidget {
  const AsyncFilledButton({
    super.key,
    required this.isLoading,
    required this.label,
    this.onPressed,
  });

  /// Whether the button is in the loading state.
  ///
  /// When `true`, the button is disabled and shows a spinner.
  final bool isLoading;

  /// Text label shown when [isLoading] is `false`.
  final String label;

  /// Callback invoked when the button is tapped.
  ///
  /// Ignored (button disabled) when [isLoading] is `true`.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child:
          isLoading
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Text(label),
    );
  }
}
