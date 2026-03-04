import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/crispy_spacing.dart';

/// Height of the custom title bar in logical pixels.
const double kCrispyTitleBarHeight = 32.0;

/// Custom borderless title bar for desktop platforms.
///
/// Renders a compact 32 px bar with:
/// - [DragToMoveArea] covering the entire bar for window dragging.
/// - Left: app icon + "CrispyTivi" label.
/// - Right: minimize, maximize/restore, and close buttons.
///
/// Returns [SizedBox.shrink] on web and mobile platforms.
class CrispyTitleBar extends StatefulWidget {
  /// Creates the custom title bar.
  const CrispyTitleBar({super.key});

  @override
  State<CrispyTitleBar> createState() => _CrispyTitleBarState();
}

class _CrispyTitleBarState extends State<CrispyTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _tryAddListener();
    _checkMaximized();
  }

  void _tryAddListener() {
    try {
      windowManager.addListener(this);
    } catch (_) {
      // window_manager not initialized (e.g. in tests) — skip.
    }
  }

  @override
  void dispose() {
    try {
      windowManager.removeListener(this);
    } catch (_) {
      // window_manager not initialized — skip.
    }
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    try {
      final max = await windowManager.isMaximized();
      if (mounted && max != _isMaximized) {
        setState(() => _isMaximized = max);
      }
    } catch (_) {
      // window_manager not available in test environment — ignore.
    }
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: kCrispyTitleBarHeight,
      child: DragToMoveArea(
        child: ColoredBox(
          color: cs.surface,
          child: Row(
            children: [
              // ── Left: icon + app name ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.live_tv_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: CrispySpacing.xs),
                    Text(
                      'CrispyTivi',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Spacer — fills the drag area ──────────────────────
              const Spacer(),

              // ── Right: window controls ────────────────────────────
              // Use ExcludeFocus so D-pad navigation skips these
              // buttons (they are pointer-only on desktop).
              ExcludeFocus(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WindowButton(
                      icon: Icons.remove_rounded,
                      onTap: () => windowManager.minimize(),
                    ),
                    _WindowButton(
                      icon:
                          _isMaximized
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                      onTap:
                          () =>
                              _isMaximized
                                  ? windowManager.unmaximize()
                                  : windowManager.maximize(),
                    ),
                    _WindowButton(
                      icon: Icons.close_rounded,
                      onTap: () => windowManager.close(),
                      hoverColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact window-control button with hover highlight.
class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.hoverColor,
  });

  /// Icon to render inside the button.
  final IconData icon;

  /// Callback invoked on tap.
  final VoidCallback onTap;

  /// Background color shown on hover. Defaults to [ColorScheme.onSurface]
  /// at 12% opacity when null.
  final Color? hoverColor;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedHover =
        widget.hoverColor ?? cs.onSurface.withValues(alpha: 0.12);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: kCrispyTitleBarHeight + CrispySpacing.sm,
          height: kCrispyTitleBarHeight,
          color: _hovered ? resolvedHover : Colors.transparent,
          child: Center(
            child: Icon(
              widget.icon,
              size: 16,
              color:
                  _hovered && widget.hoverColor != null
                      ? Colors.white
                      : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
