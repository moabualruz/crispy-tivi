import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';
import 'theme_settings.dart';

/// S-12: Extracted from _AppearanceSection in settings_screen.dart.
///
/// Appearance section: theme preview card, hue slider, and accent
/// colour picker, with a per-section reset button (FE-S-03).
class AppearanceSettingsSection extends ConsumerWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      ],
    );
  }
}
