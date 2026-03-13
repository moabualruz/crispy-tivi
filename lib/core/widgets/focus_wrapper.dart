import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/crispy_animation.dart';
import '../theme/crispy_elevation.dart';
import '../theme/crispy_radius.dart';
import 'input_mode_scope.dart';

/// Focus indicator visual style.
///
/// Determines how focused/hovered state is displayed on a
/// [FocusWrapper].
enum FocusIndicatorStyle {
  /// Gradient bottom-line: 50% of element width, aligned to the
  /// leading edge (left in LTR, right in RTL). Solid from the
  /// alignment edge, fading out over the last 15% of line length.
  /// No scale. Used for nav items, buttons, text rows, pickers,
  /// and all non-card widgets.
  underline,

  /// Scale + shadow: the card scales up on focus with a box shadow.
  /// No border ring. Used for image cards (posters, channel tiles,
  /// landscape cards).
  card,
}

/// Default width (dp) of the focus-indicator border ring.
///
/// Matches `.ai/docs/project-specs/design_system.md §2.2`. Override via
/// [FocusWrapper.focusBorderWidth] when a thicker ring is needed.
const double kFocusBorderWidth = 2.0;

/// Maximum absolute pixel expansion (dp) allowed when scaling on focus.
///
/// Prevents very large cards from expanding too aggressively. The scale
/// factor is dynamically capped so neither axis grows more than this value.
const double kFocusMaxScaleExpansion = 12.0;

/// Wraps a child widget with TV-compatible focus handling per
/// `.ai/docs/project-specs/design_system.md §2.2`.
///
/// Provides:
/// - Visual focus indicator (underline or card ring + scale)
/// - Directional navigation (D-pad arrows)
/// - Optional sound on select
///
/// ```dart
/// FocusWrapper(
///   onSelect: () => playChannel(ch),
///   child: ChannelListItem(channel: ch),
/// )
/// ```
class FocusWrapper extends StatefulWidget {
  const FocusWrapper({
    required this.child,
    this.onSelect,
    this.onKeyboardActivate,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.focusStyle = FocusIndicatorStyle.underline,
    this.borderRadius = CrispyRadius.md,
    this.scaleFactor = CrispyAnimation.hoverScale,
    this.maxScaleExpansion = kFocusMaxScaleExpansion,
    this.focusBorderWidth = kFocusBorderWidth,
    this.showFocusOverlay = true,
    this.semanticLabel,
    this.onFocusChange,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// The content to wrap.
  final Widget child;

  /// Called when Enter/OK is pressed while focused.
  final VoidCallback? onSelect;

  /// Called when the item is activated via keyboard/gamepad
  /// (Enter, Select, Gamepad A). When non-null, overrides
  /// [onSelect] for keyboard activation only; [onSelect]
  /// continues to drive [GestureDetector.onTap].
  final VoidCallback? onKeyboardActivate;

  /// Called on long-press (context menu trigger).
  final VoidCallback? onLongPress;

  /// Optional custom focus node.
  final FocusNode? focusNode;

  /// Whether this widget requests focus on first build.
  final bool autofocus;

  /// Visual style of the focus indicator.
  ///
  /// [FocusIndicatorStyle.underline] (default) renders a gradient
  /// bottom-line with no scaling.
  /// [FocusIndicatorStyle.card] renders scale + glow ring for image cards.
  final FocusIndicatorStyle focusStyle;

  /// Focus indicator border radius (used by [FocusIndicatorStyle.card]).
  final double borderRadius;

  /// Scale multiplier when focused (used by [FocusIndicatorStyle.card]).
  /// Ignored for [FocusIndicatorStyle.underline].
  final double scaleFactor;

  /// Maximum absolute pixel expansion on either axis. If [scaleFactor]
  /// would cause the widget's width or height to grow by more than this
  /// value, the scale is dynamically capped. Default is 12.0 pixels.
  /// Only applies to [FocusIndicatorStyle.card].
  final double? maxScaleExpansion;

  /// Width of the focus border ring (card style) or underline thickness.
  final double focusBorderWidth;

  /// Whether to show the overlay highlight on focus.
  final bool showFocusOverlay;

  /// Accessibility label.
  final String? semanticLabel;

  /// Called when focus state changes.
  final ValueChanged<bool>? onFocusChange;

  /// Padding between the focus border and the child.
  /// Set to [EdgeInsets.zero] for borderless card layouts.
  final EdgeInsetsGeometry padding;

  @override
  State<FocusWrapper> createState() => _FocusWrapperState();
}

class _FocusWrapperState extends State<FocusWrapper> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    if (hasFocus != _isFocused) {
      setState(() => _isFocused = hasFocus);
      widget.onFocusChange?.call(hasFocus);
      if (hasFocus) {
        // Defer scroll to next frame so the widget tree
        // is stable. Guard with `mounted` and verify the
        // nearest Scrollable is still attached to avoid
        // "object.attached is not true" assertions when
        // rapid focus traversal detaches the scroll position
        // before this callback fires.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Scrollable.maybeOf(context) != null) {
            try {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: CrispyAnimation.fast,
                curve: CrispyAnimation.focusCurve,
              );
            } on AssertionError catch (_) {
              // ScrollPosition detached between the check and the call —
              // safe to ignore; the widget is leaving the tree.
            }
          }
        });
      }
    }
  }

  void _handleHoverChange(bool isHovered) {
    if (isHovered != _isHovered) {
      setState(() => _isHovered = isHovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFocus = InputModeScope.of(context);

    // In keyboard/gamepad mode: show focus indicator.
    // In mouse mode: show hover indicator only.
    // In touch mode: no indicator at all.
    final showFocusBorder = _isFocused && showFocus;
    final showHoverBorder = _isHovered && !showFocus && !_isFocused;
    final isHighlighted = showFocusBorder || showHoverBorder;

    return Semantics(
      label: widget.semanticLabel,
      button: widget.onSelect != null || widget.onKeyboardActivate != null,
      child: FocusableActionDetector(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: _handleFocusChange,
        onShowHoverHighlight: _handleHoverChange,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          // Gamepad A button → select.
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
          // Context menu shortcuts.
          SingleActivator(LogicalKeyboardKey.f10, shift: true):
              _ContextMenuIntent(),
          SingleActivator(LogicalKeyboardKey.contextMenu): _ContextMenuIntent(),
          // Gamepad X button → context menu.
          SingleActivator(LogicalKeyboardKey.gameButtonX): _ContextMenuIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              (widget.onKeyboardActivate ?? widget.onSelect)?.call();
              return null;
            },
          ),
          _ContextMenuIntent: CallbackAction<_ContextMenuIntent>(
            onInvoke: (_) {
              widget.onLongPress?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            widget.onSelect?.call();
          },
          onLongPress: widget.onLongPress,
          child: _buildContent(
            context,
            isHighlighted,
            showFocusBorder,
            showHoverBorder,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isHighlighted,
    bool showFocusBorder,
    bool showHoverBorder,
  ) {
    if (widget.focusStyle == FocusIndicatorStyle.underline) {
      return _buildUnderline(context, showFocusBorder, showHoverBorder);
    }

    // Card style — use LayoutBuilder when maxScaleExpansion is set.
    if (widget.maxScaleExpansion != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final activeScale = _computeScale(constraints);
          return _buildCardAnimated(
            context,
            isHighlighted,
            showFocusBorder,
            showHoverBorder,
            activeScale,
          );
        },
      );
    }
    return _buildCardAnimated(
      context,
      isHighlighted,
      showFocusBorder,
      showHoverBorder,
      widget.scaleFactor,
    );
  }

  // ── Underline style ──────────────────────────────────────

  Widget _buildUnderline(
    BuildContext context,
    bool showFocusBorder,
    bool showHoverBorder,
  ) {
    final color = Theme.of(context).colorScheme.primary;
    final lineColor =
        showFocusBorder
            ? color
            : showHoverBorder
            ? color.withValues(alpha: 0.4)
            : Colors.transparent;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return AnimatedContainer(
      duration: CrispyAnimation.fast,
      curve: CrispyAnimation.focusCurve,
      padding: widget.padding,
      child: CustomPaint(
        foregroundPainter: _FocusUnderlinePainter(
          color: lineColor,
          strokeWidth: widget.focusBorderWidth,
          isRtl: isRtl,
        ),
        child: widget.child,
      ),
    );
  }

  // ── Card style ───────────────────────────────────────────

  /// Computes the active scale factor, capping it so neither axis
  /// grows by more than [FocusWrapper.maxScaleExpansion] pixels.
  double _computeScale(BoxConstraints constraints) {
    double activeScale = widget.scaleFactor;
    final maxExp = widget.maxScaleExpansion;
    if (maxExp != null &&
        constraints.maxWidth < double.infinity &&
        constraints.maxHeight < double.infinity) {
      final expansionX = constraints.maxWidth * (widget.scaleFactor - 1.0);
      final expansionY = constraints.maxHeight * (widget.scaleFactor - 1.0);
      final maxExpansion = math.max(expansionX, expansionY);
      if (maxExpansion > maxExp) {
        final dominatingAxis = math.max(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        activeScale = 1.0 + (maxExp / dominatingAxis);
      }
    }
    return activeScale;
  }

  /// Builds the animated scale + container decoration (card style).
  Widget _buildCardAnimated(
    BuildContext context,
    bool isHighlighted,
    bool showFocusBorder,
    bool showHoverBorder,
    double activeScale,
  ) {
    final accentColor = Theme.of(context).colorScheme.inversePrimary;
    final borderColor =
        showFocusBorder
            ? accentColor
            : showHoverBorder
            ? accentColor.withValues(alpha: 0.4)
            : Colors.transparent;

    final radius = BorderRadius.circular(widget.borderRadius);

    return AnimatedScale(
      scale: isHighlighted ? activeScale : 1.0,
      duration: CrispyAnimation.fast,
      curve: CrispyAnimation.focusCurve,
      // Outer container: shadow + border only — no clip so
      // the glow and shadow paint outside the card bounds.
      child: AnimatedContainer(
        duration: CrispyAnimation.fast,
        curve: CrispyAnimation.focusCurve,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: borderColor,
            width: isHighlighted ? widget.focusBorderWidth : 0,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
          boxShadow:
              showFocusBorder
                  ? [
                    ...CrispyElevation.level2,
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                  : null,
        ),
        // Inner clip: rounds the child content without
        // clipping the outer shadow/border.
        child: ClipRRect(
          borderRadius: radius,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

// ── Underline painter ────────────────────────────────────────

/// Paints a directional gradient bottom-line focus indicator.
///
/// The line spans 50% of the widget width:
/// - **LTR**: left-aligned, solid from left edge, fading out at right end
/// - **RTL**: right-aligned, solid from right edge, fading out at left end
///
/// The last 15% of the line length fades from solid to transparent.
///
/// When [color] is transparent, nothing is painted.
class _FocusUnderlinePainter extends CustomPainter {
  _FocusUnderlinePainter({
    required this.color,
    required this.strokeWidth,
    required this.isRtl,
  });

  final Color color;
  final double strokeWidth;
  final bool isRtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (color == Colors.transparent || color.a == 0) return;

    final w = size.width;
    final lineLen = w * 0.5;
    final y = size.height - (strokeWidth / 2);

    // LTR: line starts at left edge (0) and extends 50% right.
    // RTL: line starts at right edge (w) and extends 50% left.
    final double solidStart;
    final double fadeEnd;
    if (isRtl) {
      fadeEnd = w - lineLen; // left end (fade)
      solidStart = w; // right end (solid)
    } else {
      solidStart = 0; // left end (solid)
      fadeEnd = lineLen; // right end (fade)
    }

    // Gradient: solid for 85% of line, then fade to transparent
    // over the last 15%.
    final paint =
        Paint()
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..shader = ui.Gradient.linear(
            Offset(solidStart, y),
            Offset(fadeEnd, y),
            [color, color, color.withValues(alpha: 0)],
            const [0.0, 0.85, 1.0],
          );

    canvas.drawLine(
      Offset(math.min(solidStart, fadeEnd), y),
      Offset(math.max(solidStart, fadeEnd), y),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FocusUnderlinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.isRtl != isRtl;
}

/// Intent for triggering context menus via keyboard/gamepad.
class _ContextMenuIntent extends Intent {
  const _ContextMenuIntent();
}
