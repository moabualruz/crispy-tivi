import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'duplicate_channels_tile.dart';
import 'settings_shared_widgets.dart';
import 'source_add_dialogs.dart';
import 'source_extra_sections.dart';
import 'source_portal_dialogs.dart';

// Re-export public API that other files import
// from this file.
export 'source_manage_dialogs.dart' show showAddXtreamDialogFromScreen;
export 'source_extra_sections.dart'
    show
        UserAgentSettingsSection,
        ContentFilterSettingsSection,
        EpgUrlSettingsSection;

/// Sources settings section: add/remove playlists,
/// Xtream, Stalker, EPG, duplicates, user agent,
/// and hidden categories.
class SourcesSettingsSection extends ConsumerStatefulWidget {
  const SourcesSettingsSection({super.key, required this.settings});

  final SettingsState settings;

  @override
  ConsumerState<SourcesSettingsSection> createState() =>
      _SourcesSettingsSectionState();
}

class _SourcesSettingsSectionState
    extends ConsumerState<SourcesSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Sources section --
        const SectionHeader(
          title: 'Sources',
          icon: Icons.playlist_add,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Add M3U Playlist'),
              subtitle: const Text('Enter URL or select a local file'),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showAddM3uDialog(
                    context: context,
                    ref: ref,
                    isMounted: () => mounted,
                  ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.api),
              title: const Text('Add Xtream Codes'),
              subtitle: const Text(
                'Enter server URL, username '
                '& password',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showAddXtreamDialog(
                    context: context,
                    ref: ref,
                    isMounted: () => mounted,
                  ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.router),
              title: const Text('Add Stalker Portal'),
              subtitle: const Text('Enter portal URL and MAC address'),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showAddStalkerDialog(
                    context: context,
                    ref: ref,
                    isMounted: () => mounted,
                  ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('EPG URL'),
              subtitle: const Text(
                'XMLTV electronic program '
                'guide source',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showEpgUrlDialog(
                    context: context,
                    ref: ref,
                    isMounted: () => mounted,
                  ),
            ),
          ],
        ),
        // -- Saved sources list --
        if (settings.sources.isNotEmpty) ...[
          const SizedBox(height: CrispySpacing.sm),
          SettingsCard(
            children: [
              for (var i = 0; i < settings.sources.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                SourceTile(
                  source: settings.sources[i],
                  onDelete:
                      () => ref
                          .read(settingsNotifierProvider.notifier)
                          .removeSource(settings.sources[i].id),
                ),
              ],
            ],
          ),
        ],
        // S-11: Extracted to DuplicateChannelsTile.
        const DuplicateChannelsTile(),
      ],
    );
  }
}
