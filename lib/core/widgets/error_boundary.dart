import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../theme/crispy_spacing.dart';

/// Error display widget with retry support.
///
/// Provides two layout modes:
/// - **Full** (default): centered column with icon, title, error detail, and retry button.
/// - **Compact**: single row with icon, truncated error text, and retry icon button.
///
/// ```dart
/// asyncValue.when(
///   data: (data) => MyWidget(data),
///   loading: () => const SkeletonRow(),
///   error: (error, _) => ErrorBoundary(
///     error: error,
///     onRetry: () => ref.invalidate(myProvider),
///   ),
/// )
/// ```
class ErrorBoundary extends StatelessWidget {
  const ErrorBoundary({
    super.key,
    required this.error,
    required this.onRetry,
    this.compact = false,
  });

  /// The error object to display.
  final Object error;

  /// Called when the user taps the retry button.
  ///
  /// When `null`, the retry button is hidden (e.g. inside
  /// [ErrorWidget.builder] where no provider context is available).
  final VoidCallback? onRetry;

  /// If `true`, renders a single-row compact layout.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: cs.error),
          const SizedBox(width: CrispySpacing.sm),
          Expanded(
            child: Text(
              error.toString(),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRetry != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRetry,
              tooltip: context.l10n.commonRetry,
            ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: CrispySpacing.md),
            Text(context.l10n.commonSomethingWentWrong, style: tt.titleMedium),
            const SizedBox(height: CrispySpacing.xs),
            Text(
              error.toString(),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: CrispySpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
