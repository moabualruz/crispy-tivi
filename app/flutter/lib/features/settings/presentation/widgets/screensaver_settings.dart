import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../player/presentation/widgets/screensaver_overlay.dart';
import 'settings_shared_widgets.dart';

/// Screensaver settings section: mode and idle timeout.
class ScreensaverSettingsSection extends ConsumerWidget {
  const ScreensaverSettingsSection({super.key, required this.settings});

  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionHeader(
          title: 'Screensaver',
          icon: Icons.nightlight_round,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Idle Timeout'),
              subtitle: Text(_timeoutLabel(settings.screensaverTimeout)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTimeoutDialog(context, ref),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: const Text('Screensaver Mode'),
              subtitle: Text(settings.screensaverMode.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showModeDialog(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  String _timeoutLabel(int minutes) {
    if (minutes <= 0) return 'Disabled';
    if (minutes == 1) return '1 minute';
    return '$minutes minutes';
  }

  void _showTimeoutDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Screensaver Idle Timeout'),
            children:
                kScreensaverTimeoutOptions.map((minutes) {
                  final isSelected = minutes == settings.screensaverTimeout;
                  return SimpleDialogOption(
                    onPressed: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setScreensaverTimeout(minutes);
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
                          _timeoutLabel(minutes),
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

  void _showModeDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Screensaver Mode'),
            children:
                ScreensaverMode.values.map((mode) {
                  final isSelected = mode == settings.screensaverMode;
                  return SimpleDialogOption(
                    onPressed: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setScreensaverMode(mode);
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
                          mode.label,
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
