import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_spacing.dart';
import '../utils/device_form_factor.dart';

/// A floating action button that appears after the user scrolls past
/// [showThreshold] pixels and smoothly animates back to the top when tapped.
///
/// The button is suppressed entirely on TV form factors, where D-pad
/// navigation makes a scroll-to-top button redundant.
///
/// Place this widget inside a [Stack] above the scrollable content,
/// or return it as the `floatingActionButton` of a [Scaffold]. The
/// [ScrollController] must be attached to the target scrollable.
///
/// ```dart
/// Scaffold(
///   floatingActionButton: ScrollToTopFAB(
///     scrollController: _scrollController,
///   ),
///   body: ListView.builder(
///     controller: _scrollController,
///     ...
///   ),
/// )
/// ```
class ScrollToTopFAB extends StatelessWidget {
  /// Creates a scroll-to-top FAB.
  const ScrollToTopFAB({
    super.key,
    required this.scrollController,
    this.showThreshold = 400.0,
    this.heroTag = 'scrollToTop',
  });

  /// The controller attached to the scrollable that this FAB drives.
  final ScrollController scrollController;

  /// Scroll offset in logical pixels above which the FAB becomes visible.
  ///
  /// Defaults to 400 px, which is roughly one screen height on most phones.
  final double showThreshold;

  /// Hero tag forwarded to [FloatingActionButton.small] to avoid tag
  /// conflicts when multiple FABs exist on a page.
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    // TV users navigate with D-pad — a scroll-to-top FAB adds no value.
    if (DeviceFormFactorService.current.isTV) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: scrollController,
      builder: (context, _) {
        final show =
            scrollController.hasClients &&
            scrollController.offset > showThreshold;

        return AnimatedSlide(
          duration: CrispyAnimation.normal,
          curve: CrispyAnimation.enterCurve,
          offset: show ? Offset.zero : const Offset(0, 2),
          child: AnimatedOpacity(
            duration: CrispyAnimation.normal,
            opacity: show ? 1.0 : 0.0,
            child: Padding(
              padding: const EdgeInsets.all(CrispySpacing.md),
              child: FloatingActionButton.small(
                heroTag: heroTag,
                tooltip: 'Scroll to top',
                onPressed:
                    () => scrollController.animateTo(
                      0,
                      duration: CrispyAnimation.slow,
                      curve: CrispyAnimation.enterCurve,
                    ),
                child: const Icon(Icons.arrow_upward),
              ),
            ),
          ),
        );
      },
    );
  }
}
