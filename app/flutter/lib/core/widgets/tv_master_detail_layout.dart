import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/crispy_animation.dart';

/// A master-detail layout where the detail panel **slides over** the
/// master content from the right edge, without resizing the master.
///
/// [showDetail] controls visibility. When `false`, master takes full
/// width. When `true`, a panel covering [detailWidthFraction] of the
/// screen slides in from the right, overlaying the master.
///
/// Back/Escape or tapping the scrim area dismisses via
/// [onDetailDismissed].
class TvMasterDetailLayout extends StatefulWidget {
  const TvMasterDetailLayout({
    required this.masterPanel,
    required this.detailPanel,
    this.showDetail = false,
    this.onDetailDismissed,
    this.detailWidthFraction = 0.4,
    // Legacy flex params ignored — kept for source compat.
    this.masterFlex = 2,
    this.detailFlex = 3,
    super.key,
  });

  final Widget masterPanel;
  final Widget detailPanel;

  /// Whether the detail panel is visible.
  final bool showDetail;

  /// Called when user presses Back, Escape, or taps the scrim.
  final VoidCallback? onDetailDismissed;

  /// Fraction of screen width the detail panel occupies (0.0–1.0).
  final double detailWidthFraction;

  /// Legacy flex params — unused in overlay mode but kept so existing
  /// call sites that pass them don't break.
  final int masterFlex;
  final int detailFlex;

  @override
  State<TvMasterDetailLayout> createState() => _TvMasterDetailLayoutState();
}

class _TvMasterDetailLayoutState extends State<TvMasterDetailLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scrimAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: CrispyAnimation.normal,
      vsync: this,
      value: widget.showDetail ? 1.0 : 0.0,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: CrispyAnimation.enterCurve,
        reverseCurve: CrispyAnimation.exitCurve,
      ),
    );
    _scrimAnimation = Tween<double>(
      begin: 0.0,
      end: 0.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(TvMasterDetailLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showDetail != oldWidget.showDetail) {
      if (widget.showDetail) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() => widget.onDetailDismissed?.call();

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        widget.showDetail &&
        widget.onDetailDismissed != null) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.browserBack) {
        _dismiss();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Master — always full width.
        Positioned.fill(child: widget.masterPanel),

        // Scrim — tappable dark overlay when detail is open.
        if (widget.showDetail || _controller.isAnimating)
          AnimatedBuilder(
            animation: _scrimAnimation,
            builder:
                (context, _) => GestureDetector(
                  onTap: _dismiss,
                  behavior: HitTestBehavior.opaque,
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: _scrimAnimation.value,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
          ),

        // Detail panel — slides in from right edge.
        if (widget.showDetail || _controller.isAnimating)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width:
                MediaQuery.sizeOf(context).width * widget.detailWidthFraction,
            child: SlideTransition(
              position: _slideAnimation,
              child: Focus(
                onKeyEvent: _handleKeyEvent,
                child: PopScope(
                  canPop: !widget.showDetail,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && widget.showDetail) _dismiss();
                  },
                  child: Material(
                    elevation: 8,
                    color: Theme.of(context).colorScheme.surface,
                    child: widget.detailPanel,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
