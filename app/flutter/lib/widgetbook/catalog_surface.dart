import 'package:flutter/material.dart';

class CatalogSurface extends StatelessWidget {
  const CatalogSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(padding: const EdgeInsets.all(32), child: child),
      ),
    );
  }
}
