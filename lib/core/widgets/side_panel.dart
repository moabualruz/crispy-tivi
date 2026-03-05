import 'package:flutter/material.dart';
import '../theme/crispy_animation.dart';
import '../theme/crispy_spacing.dart';
import 'glass_surface.dart';

/// A side panel that slides in from the right.
///
/// Used for TV layouts to display lists of options (Audio, Subtitles, etc.)
/// without obscuring the entire screen.
class SidePanel extends StatefulWidget {
  const SidePanel({
    required this.title,
    required this.child,
    this.onClose,
    this.width = 400,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final double width;

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CrispyAnimation.normal,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _controller.reverse().then((_) {
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Backdrop - tap to close
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: Container(color: Colors.black54),
          ),
        ),

        // Panel
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: widget.width,
          child: SlideTransition(
            position: _slideAnimation,
            child: GlassSurface(
              borderRadius: 0,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(CrispySpacing.lg),
                    child: Row(
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: 'Close panel',
                          onPressed: _close,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),

                  // Content
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
