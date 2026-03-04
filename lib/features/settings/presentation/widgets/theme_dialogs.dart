import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/accent_color.dart';
import '../../../../core/theme/main_color_hue.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/theme_provider.dart';

/// Shows the main color hue selection dialog.
void showMainHueDialog(
  BuildContext context,
  WidgetRef ref,
  MainColorHue currentHue,
) {
  showDialog(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Theme Base'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  MainColorHue.values.map((hue) {
                    final isSelected = hue == currentHue;
                    return MainHueOption(
                      hue: hue,
                      isSelected: isSelected,
                      onTap: () {
                        ref.read(themeProvider.notifier).setMainHue(hue);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
  );
}

/// Shows the accent color selection dialog.
void showAccentColorDialog(
  BuildContext context,
  WidgetRef ref,
  AccentColor currentAccent,
  Color? customAccent,
) {
  showDialog(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Accent Color'),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 12,
              runSpacing: 16,
              children:
                  AccentColor.values.where((a) => a != AccentColor.custom).map((
                    accent,
                  ) {
                    final isSelected = accent == currentAccent;
                    return AccentColorChip(
                      color: accent.color!,
                      label: accent.displayName,
                      isSelected: isSelected,
                      onTap: () {
                        ref.read(themeProvider.notifier).setAccent(accent);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
  );
}

/// Shows the UI density selection dialog.
void showDensityDialog(
  BuildContext context,
  WidgetRef ref,
  UiDensity currentDensity,
) {
  showDialog(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('UI Density'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  UiDensity.values.map((density) {
                    final isSelected = density == currentDensity;
                    return DensityOption(
                      density: density,
                      isSelected: isSelected,
                      onTap: () {
                        ref.read(themeProvider.notifier).setDensity(density);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
  );
}

/// Option tile for main color hue selection.
class MainHueOption extends StatelessWidget {
  const MainHueOption({
    required this.hue,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final MainColorHue hue;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CrispyRadius.tv),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: CrispySpacing.sm,
          horizontal: CrispySpacing.xs,
        ),
        child: Row(
          children: [
            // Color preview
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hue.surface,
                borderRadius: BorderRadius.circular(CrispyRadius.tv),
                border: Border.all(color: colorScheme.outline, width: 1),
              ),
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: hue.raised,
                    borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  ),
                ),
              ),
            ),
            const SizedBox(width: CrispySpacing.md),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hue.displayName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    hue.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Option tile for UI density selection.
class DensityOption extends StatelessWidget {
  const DensityOption({
    required this.density,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final UiDensity density;
  final bool isSelected;
  final VoidCallback onTap;

  String get _description {
    switch (density) {
      case UiDensity.compact:
        return 'Tighter spacing, smaller touch targets';
      case UiDensity.standard:
        return 'Default Material Design spacing';
      case UiDensity.comfortable:
        return 'Larger touch targets, more breathing room';
    }
  }

  IconData get _icon {
    switch (density) {
      case UiDensity.compact:
        return Icons.density_small;
      case UiDensity.standard:
        return Icons.density_medium;
      case UiDensity.comfortable:
        return Icons.density_large;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CrispyRadius.tv),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: CrispySpacing.sm,
          horizontal: CrispySpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              _icon,
              size: 28,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
            const SizedBox(width: CrispySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    density.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    _description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Circular color chip for accent color selection.
class AccentColorChip extends StatelessWidget {
  const AccentColorChip({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(CrispyRadius.tv),
              border:
                  isSelected
                      ? Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 3,
                      )
                      : null,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child:
                isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : null,
          ),
        ),
        const SizedBox(height: CrispySpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
