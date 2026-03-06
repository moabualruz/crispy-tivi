import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Live TV settings section: default screen after login
/// and auto-resume last channel.
class LiveTvSettingsSection extends ConsumerWidget {
  const LiveTvSettingsSection({super.key, required this.settings});

  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: 'Live TV',
          icon: Icons.live_tv,
          colorTitle: true,
          trailing: IconButton(
            icon: const Icon(Icons.restore, size: 20),
            tooltip: 'Reset to defaults',
            onPressed:
                () => showSettingsResetDialog(
                  context,
                  ref,
                  'Reset Live TV Settings',
                  'liveTV',
                ),
          ),
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Default screen after login'),
              subtitle: Text(_defaultScreenLabel(settings.defaultScreen)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDefaultScreenDialog(context, ref),
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.replay),
              title: const Text('Auto-resume last channel'),
              subtitle: const Text(
                'Start playing the last channel when '
                'opening Live TV',
              ),
              value: settings.autoResumeChannel,
              onChanged: (val) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setAutoResumeChannel(val);
              },
            ),
          ],
        ),
      ],
    );
  }

  String _defaultScreenLabel(String screen) {
    switch (screen) {
      case 'live_tv':
        return 'Live TV';
      case 'home':
      default:
        return 'Home';
    }
  }

  void _showDefaultScreenDialog(BuildContext context, WidgetRef ref) {
    const options = [('home', 'Home'), ('live_tv', 'Live TV')];

    showDialog<void>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Default screen after login'),
            children:
                options.map((opt) {
                  final (value, label) = opt;
                  final isSelected = value == settings.defaultScreen;

                  return SimpleDialogOption(
                    onPressed: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setDefaultScreen(value);
                      Navigator.pop(ctx);
                    },
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                          size: 20,
                        ),
                        const SizedBox(width: CrispySpacing.md),
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
    );
  }
}
