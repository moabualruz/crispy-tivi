import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/density_mode.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';
import 'theme_settings.dart';

/// S-12: Extracted from _AppearanceSection in settings_screen.dart.
///
/// Appearance section: theme preview card, hue slider, accent
/// colour picker, grid density selector, and spoiler blur toggle.
class AppearanceSettingsSection extends ConsumerWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider).asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Appearance',
          icon: Icons.palette,
          colorTitle: true,
          trailing: IconButton(
            icon: const Icon(Icons.restore, size: 20),
            tooltip: 'Reset to defaults',
            onPressed:
                () => showSettingsResetDialog(
                  context,
                  ref,
                  'Reset Appearance',
                  'appearance',
                ),
          ),
        ),
        const SizedBox(height: CrispySpacing.sm),
        // Theme preview card
        const ThemePreviewCard(),
        const SizedBox(height: CrispySpacing.sm),
        // Theme settings (main hue + accent)
        const SettingsCard(children: [ThemeSettingsSection()]),
        const SizedBox(height: CrispySpacing.sm),
        // Grid density + visual polish
        if (settings != null)
          SettingsCard(
            children: [
              _GridDensityTile(
                density: settings.gridDensity,
                onChanged: (mode) {
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .setGridDensity(mode);
                },
              ),
              _VodDisplayModeTile(
                mode: settings.vodDisplayMode,
                onChanged: (mode) {
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .setVodDisplayMode(mode);
                },
              ),
              SwitchListTile(
                title: const Text('Spoiler blur'),
                subtitle: const Text('Blur thumbnails for unwatched episodes'),
                secondary: const Icon(Icons.visibility_off_outlined),
                value: settings.spoilerBlurEnabled,
                onChanged: (v) {
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .setSpoilerBlurEnabled(v);
                },
              ),
            ],
          ),
      ],
    );
  }
}

/// Segmented button for [DensityMode] selection.
class _GridDensityTile extends StatelessWidget {
  const _GridDensityTile({required this.density, required this.onChanged});

  final DensityMode density;
  final ValueChanged<DensityMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(density.icon),
      title: const Text('Grid density'),
      subtitle: Text(density.label),
      trailing: SegmentedButton<DensityMode>(
        segments: [
          for (final mode in DensityMode.values)
            ButtonSegment(
              value: mode,
              icon: Icon(mode.icon),
              tooltip: mode.label,
            ),
        ],
        selected: {density},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
      ),
    );
  }
}

/// Toggle between poster and banner display for VOD items.
class _VodDisplayModeTile extends StatelessWidget {
  const _VodDisplayModeTile({required this.mode, required this.onChanged});

  final VodDisplayMode mode;
  final ValueChanged<VodDisplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('VOD banner view'),
      subtitle: const Text('Show landscape banners instead of posters'),
      secondary: Icon(
        mode == VodDisplayMode.banner ? Icons.panorama : Icons.photo_library,
      ),
      value: mode == VodDisplayMode.banner,
      onChanged: (v) {
        onChanged(v ? VodDisplayMode.banner : VodDisplayMode.poster);
      },
    );
  }
}
