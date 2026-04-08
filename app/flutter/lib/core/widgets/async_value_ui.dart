import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_boundary.dart';
import 'loading_state_widget.dart';

/// Convenience extensions on [AsyncValue] for common UI patterns.
extension AsyncValueUi<T> on AsyncValue<T> {
  /// Standard full-page `.when` with [LoadingStateWidget] and
  /// [ErrorBoundary].
  ///
  /// Use when the async value controls an entire screen region and
  /// a visible loading spinner + error message are appropriate.
  ///
  /// Pass [onRetry] to show a retry button on error (e.g.
  /// `() => ref.invalidate(myProvider)`).
  ///
  /// ```dart
  /// ref.watch(myProvider).whenUi(
  ///   data: (value) => MyWidget(value),
  ///   onRetry: () => ref.invalidate(myProvider),
  /// );
  /// ```
  Widget whenUi({
    required Widget Function(T data) data,
    VoidCallback? onRetry,
  }) => when(
    loading: () => const LoadingStateWidget(),
    error: (e, _) => ErrorBoundary(error: e, onRetry: onRetry),
    data: data,
  );

  /// Silent `.when` — returns [SizedBox.shrink] for loading and error.
  ///
  /// Use when the async value controls a small widget that should
  /// simply disappear during loading or on error (e.g. a compact
  /// avatar, an inline badge, or a secondary row).
  ///
  /// ```dart
  /// ref.watch(myProvider).whenShrink(data: (value) => MyWidget(value));
  /// ```
  Widget whenShrink({required Widget Function(T data) data}) => when(
    loading: () => const SizedBox.shrink(),
    error: (_, _) => const SizedBox.shrink(),
    data: data,
  );
}
