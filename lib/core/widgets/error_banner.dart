import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_radius.dart';
import '../theme/crispy_spacing.dart';

/// Inline error banner for refresh errors where stale data is still visible.
///
/// Unlike [ErrorBoundary] which replaces content with a full-screen error,
/// [ErrorBanner] shows a compact banner at the top of the screen while
/// keeping the existing (stale) data visible below.
///
/// Tapping the message expands to show technical error details for
/// power users.
///
/// ```dart
/// ErrorBanner(
///   message: 'Failed to refresh channels',
///   technicalDetail: error.toString(),
///   onRetry: () => ref.invalidate(channelsProvider),
/// )
/// ```
class ErrorBanner extends StatefulWidget {
  /// Creates an inline error banner.
  const ErrorBanner({
    required this.message,
    required this.onRetry,
    this.technicalDetail,
    super.key,
  });

  /// User-friendly error message.
  final String message;

  /// Optional technical error details (shown on expand).
  final String? technicalDetail;

  /// Called when the user taps the retry button.
  final VoidCallback onRetry;

  @override
  State<ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<ErrorBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.all(CrispySpacing.sm),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(CrispyRadius.sm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap:
                widget.technicalDetail != null
                    ? () => setState(() => _expanded = !_expanded)
                    : null,
            borderRadius: BorderRadius.circular(CrispyRadius.sm),
            child: Padding(
              padding: const EdgeInsets.all(CrispySpacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: cs.onErrorContainer,
                  ),
                  const SizedBox(width: CrispySpacing.sm),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: cs.onErrorContainer),
                    onPressed: widget.onRetry,
                    iconSize: 20,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.technicalDetail != null)
            AnimatedSize(
              duration: CrispyAnimation.fast,
              curve: CrispyAnimation.enterCurve,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CrispySpacing.sm,
                  0,
                  CrispySpacing.sm,
                  CrispySpacing.sm,
                ),
                child: Text(
                  widget.technicalDetail!,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onErrorContainer.withValues(alpha: 0.7),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
