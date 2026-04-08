import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/accent_color.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../../core/theme/main_color_hue.dart';
import '../../../../core/theme/theme_provider.dart';
import 'theme_dialogs.dart';
import 'theme_sliders.dart';

/// Re-export extracted widgets so existing imports of
/// `theme_settings.dart` still find [ThemePreviewCard].
export 'theme_preview_card.dart';

/// Theme settings section for selecting main color hue
/// and accent color.
class ThemeSettingsSection extends ConsumerWidget {
  const ThemeSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Color Hue
        ListTile(
          leading: const Icon(Icons.dark_mode),
          title: const Text('Theme Base'),
          subtitle: Text(themeState.mainHue.displayName),
          trailing: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: themeState.mainHue.surface,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: colorScheme.outline, width: 1),
            ),
          ),
          onTap: () => showMainHueDialog(context, ref, themeState.mainHue),
        ),
        const Divider(height: 1),

        // Accent Color
        ListTile(
          leading: const Icon(Icons.color_lens),
          title: const Text('Accent Color'),
          subtitle: Text(themeState.accent.displayName),
          trailing: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: themeState.primaryColor,
              borderRadius: BorderRadius.zero,
            ),
          ),
          onTap:
              () => showAccentColorDialog(
                context,
                ref,
                themeState.accent,
                themeState.customAccent,
              ),
        ),
        const Divider(height: 1),

        // Text Scale
        TextScaleSlider(
          currentScale: themeState.textScale,
          onChanged: (scale) {
            ref.read(themeProvider.notifier).setTextScale(scale);
          },
        ),
        const Divider(height: 1),

        // UI Density
        ListTile(
          leading: const Icon(Icons.density_medium),
          title: const Text('UI Density'),
          subtitle: Text(
            '${themeState.density.label} · Adjusts spacing in lists and controls',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDensityDialog(context, ref, themeState.density),
        ),
        // Glass Transparency — backdrop blur only applies on mobile;
        // hide slider on desktop where it has no visual effect.
        if (PlatformCapabilities.haptic) ...[
          const Divider(height: 1),
          GlassOpacitySlider(
            currentOpacity: themeState.glassOpacity,
            onChanged: (opacity) {
              ref.read(themeProvider.notifier).setGlassOpacity(opacity);
            },
          ),
        ],
      ],
    );
  }
}
