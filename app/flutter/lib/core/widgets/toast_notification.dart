import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_radius.dart';
import '../theme/crispy_spacing.dart';

/// Lightweight toast notification system using [Overlay].
///
/// Shows non-intrusive messages that auto-dismiss after a configurable
/// duration. Uses Material 3 inverse-surface colors.
///
/// ```dart
/// CrispyToast.show(
///   context,
///   message: 'Sync complete',
///   icon: Icons.check,
/// );
/// ```
class CrispyToast {
  CrispyToast._();

  static final List<_ToastEntry> _activeToasts = [];

  /// Show a toast notification.
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = CrispyAnimation.toastDuration,
    ToastPosition position = ToastPosition.bottom,
  }) {
    final overlay = Overlay.of(context);
    final entry = _ToastEntry(
      message: message,
      icon: icon,
      duration: duration,
      position: position,
      onRemove: (e) => _activeToasts.remove(e),
    );
    _activeToasts.add(entry);
    overlay.insert(entry.overlayEntry);
  }
}

/// Vertical position for the toast.
enum ToastPosition { top, bottom }

class _ToastEntry {
  _ToastEntry({
    required this.message,
    this.icon,
    required this.duration,
    required this.position,
    required this.onRemove,
  }) {
    overlayEntry = OverlayEntry(
      builder:
          (_) => _ToastWidget(
            message: message,
            icon: icon,
            duration: duration,
            position: position,
            onDismissed: _remove,
          ),
    );
  }

  final String message;
  final IconData? icon;
  final Duration duration;
  final ToastPosition position;
  final void Function(_ToastEntry) onRemove;
  late final OverlayEntry overlayEntry;

  void _remove() {
    overlayEntry.remove();
    onRemove(this);
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    this.icon,
    required this.duration,
    required this.position,
    required this.onDismissed,
  });

  final String message;
  final IconData? icon;
  final Duration duration;
  final ToastPosition position;
  final VoidCallback onDismissed;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CrispyAnimation.normal,
    );

    final slideBegin =
        widget.position == ToastPosition.bottom
            ? const Offset(0, 1)
            : const Offset(0, -1);

    _slideAnimation = Tween<Offset>(
      begin: slideBegin,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: CrispyAnimation.enterCurve),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: CrispyAnimation.enterCurve),
    );

    _controller.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _dismissTimer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isBottom = widget.position == ToastPosition.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: isBottom ? CrispySpacing.lg : null,
      top: isBottom ? null : CrispySpacing.lg,
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Align(
              alignment:
                  isBottom ? Alignment.bottomCenter : Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(CrispyRadius.md),
                  color: cs.inverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.md,
                      vertical: CrispySpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: 20,
                            color: cs.onInverseSurface,
                          ),
                          const SizedBox(width: CrispySpacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            widget.message,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onInverseSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
