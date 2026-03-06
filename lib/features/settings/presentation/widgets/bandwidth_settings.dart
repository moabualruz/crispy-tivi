import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_selection_dialog.dart';
import 'settings_shared_widgets.dart';

// FE-S-04: Data & Bandwidth settings section.
/// Bandwidth / Data Usage settings section.
///
/// Exposes a global quality cap dropdown, a cellular data limit toggle
/// (mobile only), and a data-saving mode toggle.
class BandwidthSettingsSection extends ConsumerWidget {
  const BandwidthSettingsSection({super.key, required this.settings});

  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Data & Bandwidth',
          icon: Icons.data_usage,
          colorTitle: true,
          trailing: IconButton(
            icon: const Icon(Icons.restore, size: 20),
            tooltip: 'Reset to defaults',
            onPressed:
                () => showSettingsResetDialog(
                  context,
                  ref,
                  'Reset Data & Bandwidth',
                  'bandwidth',
                ),
          ),
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            // ── Global quality cap ──────────────────────
            ListTile(
              leading: const Icon(Icons.hd),
              title: const Row(
                children: [
                  Text('Quality Cap'),
                  SizedBox(width: CrispySpacing.sm),
                  SettingsBadge.experimental(),
                ],
              ),
              subtitle: Text(settings.qualityCap.label),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showSettingsSelectionDialog<QualityCap>(
                    context: context,
                    title: 'Quality Cap',
                    options: QualityCap.values,
                    currentValue: settings.qualityCap,
                    getLabel: (cap) => cap.label,
                    onSelect: (cap) => notifier.setQualityCap(cap),
                    isMounted: () => context.mounted,
                  ),
            ),
            const Divider(height: 1),

            // ── Data-saving mode ────────────────────────
            SwitchListTile(
              secondary: const Icon(Icons.data_saver_off),
              title: const Row(
                children: [
                  Text('Data-Saving Mode'),
                  SizedBox(width: CrispySpacing.sm),
                  SettingsBadge.experimental(),
                ],
              ),
              subtitle: const Text(
                'Prefer lower-bitrate streams to '
                'reduce data usage',
              ),
              value: settings.dataSavingMode,
              onChanged: notifier.setDataSavingMode,
            ),

            // ── Cellular data limit (mobile only) ───────
            if (PlatformCapabilities.haptic) ...[
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.signal_cellular_alt),
                title: const Row(
                  children: [
                    Text('Limit on Cellular'),
                    SizedBox(width: CrispySpacing.sm),
                    SettingsBadge.experimental(),
                  ],
                ),
                subtitle: const Text(
                  'Restrict to SD quality when '
                  'connected via mobile data',
                ),
                value: settings.cellularDataLimitEnabled,
                onChanged: notifier.setCellularDataLimitEnabled,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
