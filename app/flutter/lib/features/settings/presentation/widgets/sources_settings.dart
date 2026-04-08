import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_animation.dart';
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
        EpgUrlSettingsSection,
        SourceTlsSettingsSection,
        StalkerAccountInfoSection;

/// Sources settings section: add/remove playlists,
/// Xtream, Stalker, EPG, media servers, duplicates,
/// user agent, and hidden categories.
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
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('Add Plex Server'),
              subtitle: const Text('Connect to your Plex Media Server'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.plexLogin),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cast_connected_rounded),
              title: const Text('Add Emby Server'),
              subtitle: const Text('Connect to your Emby server'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.embyLogin),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.dns_rounded),
              title: const Text('Add Jellyfin Server'),
              subtitle: const Text('Connect to your Jellyfin server'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.jellyfinLogin),
            ),
          ],
        ),
        // -- Saved sources list (reorderable) --
        if (settings.sources.isNotEmpty) ...[
          const SizedBox(height: CrispySpacing.sm),
          SettingsCard(
            // SettingsCard wraps children in a Column. We use a
            // ReorderableListView here, so we wrap in a SizedBox with a
            // computed height: each SourceTile is ~72 dp, clamped to 360 dp.
            children: [
              SizedBox(
                height: (settings.sources.length * 72.0).clamp(0.0, 360.0),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: settings.sources.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .reorderSources(oldIndex, newIndex);
                  },
                  proxyDecorator: _proxyDecorator,
                  itemBuilder: (context, i) {
                    final source = settings.sources[i];
                    return KeyedSubtree(
                      key: ValueKey(source.id),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i > 0) const Divider(height: 1),
                          SourceTile(
                            source: source,
                            index: i,
                            showDragHandle: true,
                            onDelete:
                                () => ref
                                    .read(settingsNotifierProvider.notifier)
                                    .removeSource(source.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
        // S-11: Extracted to DuplicateChannelsTile.
        const DuplicateChannelsTile(),
      ],
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = Tween<double>(begin: 1.0, end: 1.05).animate(
          CurvedAnimation(parent: animation, curve: CrispyAnimation.focusCurve),
        );
        return Transform.scale(
          scale: scale.value,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.zero,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
