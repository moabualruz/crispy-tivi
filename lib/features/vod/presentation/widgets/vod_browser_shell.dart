import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_boundary.dart';
import '../../../../core/widgets/vod_grid_loading_shell.dart';
import 'vod_movies_grid.dart' show vodMaxExtent;

/// Shared loading / error / empty guard triad for VOD browser screens.
///
/// When [isLoading] is true, renders a [Scaffold] with an [AppBar] titled
/// [title] and a [VodGridLoadingShell] body.
///
/// When [error] is non-null, renders a bare [Scaffold] with an
/// [ErrorStateWidget].
///
/// When [isEmpty] is true, renders a bare [Scaffold] with an
/// [EmptyStateWidget] using the caller-supplied icon and text.
///
/// Otherwise returns [child] unchanged — callers are responsible for
/// wrapping the loaded content in their own [Scaffold].
///
/// ```dart
/// return VodBrowserShell(
///   title: 'Movies',
///   isLoading: state.isLoading,
///   error: state.error,
///   isEmpty: state.items.isEmpty,
///   emptyIcon: Icons.movie_outlined,
///   emptyTitle: 'No movies available',
///   emptyDescription: 'Add a playlist source in Settings',
///   child: myLoadedScaffold,
/// );
/// ```
class VodBrowserShell extends StatelessWidget {
  const VodBrowserShell({
    required this.title,
    required this.isLoading,
    required this.error,
    required this.isEmpty,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.child,
    this.onRetry,
    super.key,
  });

  /// AppBar title shown in the loading state.
  final String title;

  /// When true, the loading skeleton is shown.
  final bool isLoading;

  /// Non-null error string triggers the error state.
  final String? error;

  /// When true (and [error] is null and [isLoading] is false), the
  /// empty-state placeholder is shown.
  final bool isEmpty;

  /// Icon for the empty-state placeholder.
  final IconData emptyIcon;

  /// Primary message for the empty-state placeholder.
  final String emptyTitle;

  /// Secondary hint for the empty-state placeholder.
  final String emptyDescription;

  /// Called when the user taps the retry button in the error state.
  final VoidCallback? onRetry;

  /// Widget returned as-is when content is available.
  ///
  /// Must include its own [Scaffold]; this shell does not wrap it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: VodGridLoadingShell(maxCrossAxisExtent: vodMaxExtent(context)),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorBoundary(error: error!, onRetry: onRetry ?? () {}),
      );
    }
    if (isEmpty) {
      return Scaffold(
        body: EmptyStateWidget(
          icon: emptyIcon,
          title: emptyTitle,
          description: emptyDescription,
          showSettingsButton: true,
        ),
      );
    }
    return child;
  }
}
