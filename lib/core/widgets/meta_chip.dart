import 'package:flutter/material.dart';

import '../theme/crispy_spacing.dart';

/// Inline metadata chip for hero banner overlays
/// (year, rating, duration, category).
///
/// Uses design tokens from [CrispySpacing]. Never hardcode px values.
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: CrispySpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
