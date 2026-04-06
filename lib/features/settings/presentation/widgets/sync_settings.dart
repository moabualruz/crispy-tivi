import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/presentation/providers/playlist_sync_service.dart';
import '../providers/settings_service_providers.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Sync settings section: sync interval, sync now,
/// and web local data sync.
class SyncSettingsSection extends ConsumerStatefulWidget {
  const SyncSettingsSection({super.key, required this.settings});

  final SettingsState settings;

  @override
  ConsumerState<SyncSettingsSection> createState() =>
      _SyncSettingsSectionState();
}

class _SyncSettingsSectionState extends ConsumerState<SyncSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Web Local Sync (WASM Native Style) ──
        if (kIsWeb) ...[
          const SectionHeader(
            title: 'Local Data',
            icon: Icons.folder_open,
            colorTitle: true,
          ),
          const SizedBox(height: CrispySpacing.sm),
          SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text('Select Sync Folder'),
                subtitle: const Text(
                  'Choose a local folder to store '
                  'your data',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  try {
                    final service = ref.read(webSyncServiceProvider);
                    await service.pickSyncFolder();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Folder selected '
                            'successfully',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Save to Local'),
                subtitle: const Text('Coming soon'),
                enabled: false,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Load from Local'),
                subtitle: const Text('Coming soon'),
                enabled: false,
              ),
            ],
          ),
          const SizedBox(height: CrispySpacing.lg),
        ],

        // ── Sync section ──
        const SectionHeader(title: 'Sync', icon: Icons.sync, colorTitle: true),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Sync Interval'),
              subtitle: Text('Every ${settings.syncIntervalHours}h'),
              trailing: DropdownButton<int>(
                value: settings.syncIntervalHours,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1h')),
                  DropdownMenuItem(value: 6, child: Text('6h')),
                  DropdownMenuItem(value: 12, child: Text('12h')),
                  DropdownMenuItem(value: 24, child: Text('24h')),
                  DropdownMenuItem(value: 48, child: Text('48h')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .setSyncInterval(val);
                  }
                },
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.movie_filter),
              title: const Text('Enrich VOD on Sync'),
              subtitle: const Text(
                'Fetch full movie details during sync '
                '(slower but complete metadata)',
              ),
              value: settings.enrichVodOnSync,
              onChanged: (val) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setEnrichVodOnSync(val);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Sync Now'),
              subtitle: const Text(
                'Force re-sync all sources '
                'immediately',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Syncing all sources...')),
                );

                final syncService = ref.read(playlistSyncServiceProvider);
                final count = await syncService.syncAll(force: true);

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Synced $count channels')),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
