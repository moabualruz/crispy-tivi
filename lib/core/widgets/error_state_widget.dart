import 'package:flutter/material.dart';

import '../theme/crispy_spacing.dart';

/// A centered column displaying an error icon, message, and optional
/// retry button.
///
/// Use inside [Center] or directly in a [Scaffold.body] when an
/// async operation fails and no specific error UI is needed.
///
/// ```dart
/// Widget _buildError(String error) => Scaffold(
///   body: ErrorStateWidget(message: 'Failed to load: $error'),
/// );
/// ```
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({super.key, required this.message, this.onRetry});

  /// Human-readable error message shown below the icon.
  final String message;

  /// If provided, a Retry button is shown below the message.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: CrispySpacing.md),
          Text(message),
          if (onRetry != null) ...[
            const SizedBox(height: CrispySpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
