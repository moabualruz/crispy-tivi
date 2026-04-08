import 'package:flutter/widgets.dart';

/// A [FocusScope] wrapper that catches focus traversal exceptions.
///
/// Use this instead of raw [FocusScope] in screen-level layouts
/// to prevent disposed or detached [FocusNode]s from crashing the
/// widget tree.
///
/// Optionally accepts a [restorationKey] for integration with
/// [FocusRestorationService] (route-level focus tracking).
class SafeFocusScope extends StatefulWidget {
  /// Creates a safe focus scope.
  const SafeFocusScope({
    required this.child,
    this.restorationKey,
    this.autofocus = false,
    super.key,
  });

  /// The widget subtree to wrap in a [FocusScope].
  final Widget child;

  /// Optional key for focus restoration across navigation.
  ///
  /// When provided, [FocusRestorationService] can use this to
  /// store and retrieve the last-focused element for this scope.
  final String? restorationKey;

  /// Whether the scope should auto-request focus on first build.
  final bool autofocus;

  @override
  State<SafeFocusScope> createState() => _SafeFocusScopeState();
}

class _SafeFocusScopeState extends State<SafeFocusScope> {
  late final FocusScopeNode _scopeNode;

  @override
  void initState() {
    super.initState();
    _scopeNode = FocusScopeNode(
      debugLabel: widget.restorationKey ?? 'SafeFocusScope',
    );
  }

  @override
  void dispose() {
    _scopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _scopeNode,
      autofocus: widget.autofocus,
      child: widget.child,
    );
  }
}
