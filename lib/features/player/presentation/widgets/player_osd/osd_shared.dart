import 'package:flutter/material.dart';

/// Top gradient: black 0.7 at top fading to transparent.
const osdTopGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xB3000000), // rgba(0,0,0,0.7)
    Colors.transparent,
  ],
);

/// Bottom gradient: black 0.7 at bottom fading to
/// transparent.
const osdBottomGradient = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: [
    Color(0xB3000000), // rgba(0,0,0,0.7)
    Colors.transparent,
  ],
);

/// Panel background for audio/subtitle picker.
const osdPanelColor = Color(0xD91A1A1A); // #1A1A1A @ 85%

/// Height reserved for the OSD bottom bar, used by overlays
/// (completion, next-episode) to position above the controls.
const kOsdBottomBarHeight = 80.0;

/// Reusable icon button for the OSD bar.
class OsdIconButton extends StatelessWidget {
  const OsdIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.iconColor,
    this.order,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? iconColor;

  /// Focus traversal order within the OSD bar.
  final double? order;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    Widget button = Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: enabled ? (iconColor ?? Colors.white) : Colors.white24,
          size: 22,
        ),
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.2);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.1);
            }
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: Colors.white, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
    );
    if (order != null) {
      button = FocusTraversalOrder(
        order: NumericFocusOrder(order!),
        child: button,
      );
    }
    return button;
  }
}

/// Aspect ratio icon helper.
IconData aspectRatioIcon(String label) {
  switch (label) {
    case 'Original':
      return Icons.crop_free;
    case '16:9':
      return Icons.crop_16_9;
    case '4:3':
      return Icons.crop_7_5;
    case 'Fill':
      return Icons.fullscreen;
    case 'Fit':
      return Icons.fit_screen;
    default:
      return Icons.aspect_ratio_rounded;
  }
}
