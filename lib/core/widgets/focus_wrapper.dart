import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/crispy_animation.dart';
import '../theme/crispy_elevation.dart';
import '../theme/crispy_radius.dart';
import 'input_mode_scope.dart';

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
/// - Visual focus indicator (primary border + subtle scale)
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

  /// Focus indicator border radius.
  final double borderRadius;

  /// Scale multiplier when focused. 1.0 = no scale.
  final double scaleFactor;

  /// Maximum absolute pixel expansion on either axis. If [scaleFactor]
  /// would cause the widget's width or height to grow by more than this
  /// value, the scale is dynamically capped. Default is 12.0 pixels.
  final double? maxScaleExpansion;

  /// Width of the focus border ring.
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
        // is stable. Guard with `mounted` to avoid null
        // context when focus traversal disposes this widget
        // before the callback fires (BUG-001).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: CrispyAnimation.fast,
              curve: CrispyAnimation.focusCurve,
            );
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

    // In keyboard/gamepad mode: show focus border.
    // In mouse mode: show hover border only.
    // In touch mode: no border at all.
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
          // LayoutBuilder is only required when maxScaleExpansion is set
          // (to read constraints and cap the scale). When null, we skip
          // the extra layout pass for better performance.
          child:
              widget.maxScaleExpansion != null
                  ? LayoutBuilder(
                    builder: (context, constraints) {
                      final activeScale = _computeScale(constraints);
                      return _buildAnimated(
                        context,
                        isHighlighted,
                        showFocusBorder,
                        showHoverBorder,
                        activeScale,
                      );
                    },
                  )
                  : _buildAnimated(
                    context,
                    isHighlighted,
                    showFocusBorder,
                    showHoverBorder,
                    widget.scaleFactor,
                  ),
        ),
      ),
    );
  }

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

  /// Builds the animated scale + container decoration.
  Widget _buildAnimated(
    BuildContext context,
    bool isHighlighted,
    bool showFocusBorder,
    bool showHoverBorder,
    double activeScale,
  ) {
    return AnimatedScale(
      scale: isHighlighted ? activeScale : 1.0,
      duration: CrispyAnimation.fast,
      curve: CrispyAnimation.focusCurve,
      child: AnimatedContainer(
        duration: CrispyAnimation.fast,
        curve: CrispyAnimation.focusCurve,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color:
                showFocusBorder
                    ? Theme.of(context).focusColor
                    : showHoverBorder
                    ? Theme.of(context).focusColor.withValues(alpha: 0.4)
                    : Colors.transparent,
            width: widget.focusBorderWidth,
          ),
          boxShadow: showFocusBorder ? CrispyElevation.level2 : null,
        ),
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}

/// Intent for triggering context menus via keyboard/gamepad.
class _ContextMenuIntent extends Intent {
  const _ContextMenuIntent();
}
