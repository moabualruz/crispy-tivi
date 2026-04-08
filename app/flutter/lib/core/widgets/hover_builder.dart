import 'package:flutter/material.dart';

/// A wrapper that provides continuous hover state to its child builder,
/// allowing the parent widget to remain stateless.
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder});

  /// Builder function providing the current hover state.
  final Widget Function(BuildContext context, bool isHovered) builder;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _isHovered = false;

  void _updateHover(bool hovered) {
    if (_isHovered != hovered && mounted) {
      setState(() => _isHovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _updateHover(true),
      onExit: (_) => _updateHover(false),
      child: widget.builder(context, _isHovered),
    );
  }
}
