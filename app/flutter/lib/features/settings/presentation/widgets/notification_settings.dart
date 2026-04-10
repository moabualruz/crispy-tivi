import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Notifications settings section.
///
/// Controls the global in-app notification toggle and per-event
/// granular preferences (recording complete, new episode, live event
/// reminder).  Per-event toggles are placeholder UI — they persist to
/// settings but do not yet connect to a push-notification backend.
class NotificationSettingsSection extends ConsumerWidget {
  const NotificationSettingsSection({super.key, required this.settings});

  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Notifications',
          icon: Icons.notifications,
          colorTitle: true,
          trailing: IconButton(
            icon: const Icon(Icons.restore, size: 20),
            tooltip: 'Reset to defaults',
            onPressed:
                () => showSettingsResetDialog(
                  context,
                  ref,
                  'Reset Notifications',
                  'notifications',
                ),
          ),
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            // ── Global toggle ──────────────────────────────
            SwitchListTile(
              title: const Text('In-App Notifications'),
              subtitle: const Text(
                'Toasts for sync, recording and '
                'reminders',
              ),
              secondary: const Icon(Icons.notifications_active),
              value: settings.notificationsEnabled,
              onChanged: notifier.setNotificationsEnabled,
            ),

            // ── Per-event toggles (enabled only when global ──
            // ── notifications are on)                       ──
            if (settings.notificationsEnabled) ...[
              const Divider(height: 1, indent: kSettingsIndent),

              // Recording complete
              SwitchListTile(
                title: const SettingsTileTitle(
                  title: 'Recording Complete',
                  badge: SettingsBadge.experimental(),
                ),
                subtitle: const Text('Alert when a DVR recording finishes'),
                secondary: const Icon(Icons.videocam_outlined),
                value: settings.notifyRecordingComplete,
                onChanged: notifier.setNotifyRecordingComplete,
              ),
              const Divider(height: 1, indent: kSettingsIndent),

              // New episode available
              SwitchListTile(
                title: const SettingsTileTitle(
                  title: 'New Episode Available',
                  badge: SettingsBadge.experimental(),
                ),
                subtitle: const Text(
                  'Alert when a tracked series gets '
                  'a new episode',
                ),
                secondary: const Icon(Icons.new_releases_outlined),
                value: settings.notifyNewEpisode,
                onChanged: notifier.setNotifyNewEpisode,
              ),
              const Divider(height: 1, indent: kSettingsIndent),

              // Live event reminder
              SwitchListTile(
                title: const SettingsTileTitle(
                  title: 'Live Event Reminders',
                  badge: SettingsBadge.experimental(),
                ),
                subtitle: const Text(
                  'Reminder before a scheduled '
                  'live programme starts',
                ),
                secondary: const Icon(Icons.event_available_outlined),
                value: settings.notifyLiveEvent,
                onChanged: notifier.setNotifyLiveEvent,
              ),
              const Divider(height: 1, indent: kSettingsIndent),

              // FE-S-07: EPG update notification
              SwitchListTile(
                title: const SettingsTileTitle(
                  title: 'EPG Update Notification',
                  badge: SettingsBadge.experimental(),
                ),
                subtitle: const Text(
                  'Alert when programme guide data '
                  'has been refreshed',
                ),
                secondary: const Icon(Icons.update_outlined),
                value: settings.notifyEpgUpdate,
                onChanged: notifier.setNotifyEpgUpdate,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
