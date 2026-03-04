import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';

/// Slider for text scale adjustment.
class TextScaleSlider extends StatelessWidget {
  const TextScaleSlider({
    required this.currentScale,
    required this.onChanged,
    super.key,
  });

  final double currentScale;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Convert scale to percentage for display
    final percentage = (currentScale * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.text_fields,
                size: 24,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: CrispySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Text Size',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      '$percentage%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CrispySpacing.sm),
          Row(
            children: [
              Text(
                'A',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Slider(
                  value: currentScale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  label: '$percentage%',
                  onChanged: onChanged,
                ),
              ),
              Text(
                'A',
                style: TextStyle(
                  fontSize: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // Preview text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
            child: Text(
              'Preview text at $percentage% scale',
              style: TextStyle(
                fontSize: 14 * currentScale,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slider for glass surface opacity/transparency
/// adjustment.
class GlassOpacitySlider extends StatelessWidget {
  const GlassOpacitySlider({
    required this.currentOpacity,
    required this.onChanged,
    super.key,
  });

  final double currentOpacity;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = (currentOpacity * 100).round();
    final label =
        currentOpacity == 0.0
            ? 'Flat (no blur)'
            : currentOpacity == 1.0
            ? 'Full glass'
            : '$percentage%';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.blur_on,
                size: 24,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: CrispySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UI Transparency',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CrispySpacing.sm),
          Slider(
            value: currentOpacity,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: label,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
