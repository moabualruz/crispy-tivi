import 'package:flutter/material.dart';

import 'responsive_layout.dart';
import 'safe_focus_scope.dart';
import 'tv_color_button_handler.dart';
import 'tv_color_button_legend.dart';
import 'tv_scale_factor.dart';

/// Reusable screen wrapper that composes all infrastructure layers.
///
/// Nesting order (outer to inner):
/// 1. [SafeFocusScope] — route-level focus scope with restoration key
/// 2. [FocusTraversalGroup] — reading order by default, accepts custom policy
/// 3. [ResponsiveLayout] — compactBody/mediumBody/expandedBody/largeBody
///
/// Error handling is provided by the global [ErrorWidget.builder] override
/// in main.dart, which renders [ErrorBoundary] for any build errors.
///
/// Does NOT include [Scaffold] — screens own their own Scaffold
/// (different screens have different AppBar configs).
///
/// ```dart
/// Scaffold(
///   body: ScreenTemplate(
///     compactBody: MobileHome(),
///     largeBody: TvHome(),
///     focusRestorationKey: 'home',
///     colorButtonMap: {
///       TvColorButton.red: ColorButtonAction(label: 'Delete', onPressed: _delete),
///     },
///   ),
/// )
/// ```
class ScreenTemplate extends StatelessWidget {
  /// Creates a screen template wrapper.
  const ScreenTemplate({
    required this.compactBody,
    required this.largeBody,
    this.mediumBody,
    this.expandedBody,
    this.hasRail = true,
    this.hasMiniPlayer = true,
    this.focusRestorationKey,
    this.traversalPolicy,
    this.colorButtonMap,
    this.onRetry,
    super.key,
  });

  /// UI for phones (< 600dp). Always required.
  final Widget compactBody;

  /// UI for TVs (>= 1200dp). Always required.
  final Widget largeBody;

  /// UI for tablets (600-839dp). Falls back to [compactBody].
  final Widget? mediumBody;

  /// UI for desktops (840-1199dp). Falls back to [mediumBody].
  final Widget? expandedBody;

  /// Whether this screen shows a navigation rail. Default: true.
  final bool hasRail;

  /// Whether this screen shows the mini player overlay. Default: true.
  final bool hasMiniPlayer;

  /// Optional key for focus restoration across navigation.
  final String? focusRestorationKey;

  /// Custom focus traversal policy. Defaults to [ReadingOrderTraversalPolicy].
  final FocusTraversalPolicy? traversalPolicy;

  /// Optional TV color button mappings. When provided, the large body
  /// is wrapped in a [TvColorButtonHandler] and a [TvColorButtonLegend]
  /// is shown as a footer.
  final Map<TvColorButton, ColorButtonAction>? colorButtonMap;

  /// Optional retry callback for error recovery. Available to
  /// error handling widgets within this screen's subtree.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Build the large body with TV auto-scaling and optional color buttons.
    Widget effectiveLargeBody = largeBody;
    if (colorButtonMap != null && colorButtonMap!.isNotEmpty) {
      effectiveLargeBody = TvColorButtonHandler(
        colorButtonMap: colorButtonMap!,
        child: Column(
          children: [
            Expanded(child: largeBody),
            TvColorButtonLegend(colorButtonMap: colorButtonMap!),
          ],
        ),
      );
    }
    // Apply resolution-based auto-scaling on TV/large layout only.
    effectiveLargeBody = TvScaleFactor(child: effectiveLargeBody);

    return SafeFocusScope(
      restorationKey: focusRestorationKey,
      child: FocusTraversalGroup(
        policy: traversalPolicy ?? ReadingOrderTraversalPolicy(),
        child: ResponsiveLayout(
          compactBody: compactBody,
          mediumBody: mediumBody,
          expandedBody: expandedBody,
          largeBody: effectiveLargeBody,
        ),
      ),
    );
  }
}
