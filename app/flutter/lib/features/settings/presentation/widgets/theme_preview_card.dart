import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/accent_color.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/main_color_hue.dart';
import '../../../../core/theme/theme_provider.dart';

/// Compact theme preview showing current main hue +
/// accent combination.
class ThemePreviewCard extends ConsumerWidget {
  const ThemePreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);

    return Container(
      margin: const EdgeInsets.all(CrispySpacing.md),
      padding: const EdgeInsets.all(CrispySpacing.md),
      decoration: BoxDecoration(
        color: themeState.mainHue.surface,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        border: Border.all(
          color: themeState.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: themeState.primaryColor,
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                ),
              ),
              const SizedBox(width: CrispySpacing.sm),
              Text(
                'Preview',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: CrispySpacing.sm),

          // Mock card
          Container(
            padding: const EdgeInsets.all(CrispySpacing.sm),
            decoration: BoxDecoration(
              color: themeState.mainHue.raised,
              borderRadius: BorderRadius.circular(CrispyRadius.tv),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: themeState.primaryContainer,
                    borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: themeState.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: CrispySpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sample Item',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${themeState.mainHue.displayName}'
                      ' • '
                      '${themeState.accent.displayName}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
