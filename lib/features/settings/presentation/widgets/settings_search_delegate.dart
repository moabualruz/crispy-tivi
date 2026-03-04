import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../screens/settings_screen.dart';

// FE-S-01: Settings search delegate — filters all settings items by label/subtitle.
// ── Search item model ─────────────────────────────────────────────────────────

/// A searchable settings item linking a label to a [SettingsSection].
class _SettingsItem {
  const _SettingsItem({
    required this.section,
    required this.label,
    this.subtitle,
    this.icon,
  });

  final SettingsSection section;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

// ── Static settings catalogue ─────────────────────────────────────────────────

/// Full catalogue of searchable settings labels.
///
/// Each entry maps a human-readable label (and optional subtitle) to its
/// [SettingsSection]. Adding new settings tiles here keeps search in sync
/// without touching the delegate logic.
const List<_SettingsItem> _kSettingsItems = [
  // Profiles
  _SettingsItem(
    section: SettingsSection.profiles,
    label: 'Profiles',
    subtitle: 'Manage user profiles',
    icon: Icons.person_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.profiles,
    label: 'Add profile',
    subtitle: 'Create a new viewer profile',
    icon: Icons.person_add_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.profiles,
    label: 'PIN protection',
    subtitle: 'Lock profiles with a PIN',
    icon: Icons.pin_outlined,
  ),

  // Sources
  _SettingsItem(
    section: SettingsSection.sources,
    label: 'Sources',
    subtitle: 'Add and manage playlists',
    icon: Icons.playlist_add,
  ),
  _SettingsItem(
    section: SettingsSection.sources,
    label: 'Add M3U playlist',
    subtitle: 'Import a playlist from a URL or file',
    icon: Icons.add_link,
  ),
  _SettingsItem(
    section: SettingsSection.sources,
    label: 'Add Xtream source',
    subtitle: 'Connect to an Xtream Codes provider',
    icon: Icons.stream,
  ),
  _SettingsItem(
    section: SettingsSection.sources,
    label: 'Add Stalker portal',
    subtitle: 'Connect to a Stalker middleware portal',
    icon: Icons.cast_connected_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.sources,
    label: 'Duplicate channels',
    subtitle: 'Hide or merge duplicate channel entries',
    icon: Icons.content_copy_outlined,
  ),

  // Media Servers
  _SettingsItem(
    section: SettingsSection.mediaServers,
    label: 'Media servers',
    subtitle: 'Connect Jellyfin, Emby, or Plex',
    icon: Icons.dns_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.mediaServers,
    label: 'Jellyfin',
    subtitle: 'Configure Jellyfin server connection',
    icon: Icons.dns_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.mediaServers,
    label: 'Emby',
    subtitle: 'Configure Emby server connection',
    icon: Icons.dns_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.mediaServers,
    label: 'Plex',
    subtitle: 'Configure Plex server connection',
    icon: Icons.dns_outlined,
  ),

  // DVR
  _SettingsItem(
    section: SettingsSection.dvr,
    label: 'DVR & recordings',
    subtitle: 'Recording storage and schedules',
    icon: Icons.video_library_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.dvr,
    label: 'Recording path',
    subtitle: 'Choose where recordings are saved',
    icon: Icons.folder_outlined,
  ),

  // Sync
  _SettingsItem(
    section: SettingsSection.sync,
    label: 'Sync',
    subtitle: 'Playlist and EPG refresh settings',
    icon: Icons.sync,
  ),
  _SettingsItem(
    section: SettingsSection.sync,
    label: 'Auto refresh interval',
    subtitle: 'How often playlists are updated',
    icon: Icons.update,
  ),

  // Appearance
  _SettingsItem(
    section: SettingsSection.appearance,
    label: 'Appearance',
    subtitle: 'Theme, colours, and layout',
    icon: Icons.palette,
  ),
  _SettingsItem(
    section: SettingsSection.appearance,
    label: 'Theme colour',
    subtitle: 'Pick the app accent colour',
    icon: Icons.color_lens_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.appearance,
    label: 'Dark mode',
    subtitle: 'Switch between light and dark theme',
    icon: Icons.dark_mode_outlined,
  ),

  // Playback
  _SettingsItem(
    section: SettingsSection.playback,
    label: 'Playback',
    subtitle: 'Player behaviour and quality',
    icon: Icons.play_circle_outline,
  ),
  _SettingsItem(
    section: SettingsSection.playback,
    label: 'Default quality',
    subtitle: 'Preferred stream quality',
    icon: Icons.high_quality_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.playback,
    label: 'Hardware decoding',
    subtitle: 'Use GPU for video decode',
    icon: Icons.memory,
  ),
  _SettingsItem(
    section: SettingsSection.playback,
    label: 'Buffer size',
    subtitle: 'Network buffer for live streams',
    icon: Icons.speed,
  ),

  // Live TV
  _SettingsItem(
    section: SettingsSection.liveTV,
    label: 'Live TV',
    subtitle: 'EPG, channel sorting, zap behaviour',
    icon: Icons.live_tv_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.liveTV,
    label: 'EPG source',
    subtitle: 'Electronic programme guide URL',
    icon: Icons.calendar_month_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.liveTV,
    label: 'Channel sort order',
    subtitle: 'How channels are ordered in the list',
    icon: Icons.sort,
  ),

  // Remote
  _SettingsItem(
    section: SettingsSection.remote,
    label: 'Remote control',
    subtitle: 'Key mapping and remote settings',
    icon: Icons.settings_remote_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.remote,
    label: 'Key mapping',
    subtitle: 'Remap remote control buttons',
    icon: Icons.keyboard_outlined,
  ),

  // Notifications
  _SettingsItem(
    section: SettingsSection.notifications,
    label: 'Notifications',
    subtitle: 'Recording alerts and reminders',
    icon: Icons.notifications_outlined,
  ),

  // Bandwidth
  _SettingsItem(
    section: SettingsSection.bandwidth,
    label: 'Data & bandwidth',
    subtitle: 'Data limits and stream quality caps',
    icon: Icons.network_check,
  ),
  _SettingsItem(
    section: SettingsSection.bandwidth,
    label: 'Mobile data limit',
    subtitle: 'Cap quality on cellular connections',
    icon: Icons.signal_cellular_alt,
  ),

  // Storage
  _SettingsItem(
    section: SettingsSection.storage,
    label: 'Storage & cache',
    subtitle: 'Cache size and clearing options',
    icon: Icons.storage_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.storage,
    label: 'Clear cache',
    subtitle: 'Remove cached images and data',
    icon: Icons.delete_outline,
  ),

  // Content Filter
  _SettingsItem(
    section: SettingsSection.contentFilter,
    label: 'Content filter',
    subtitle: 'Hide channels or groups',
    icon: Icons.filter_list_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.contentFilter,
    label: 'Hidden groups',
    subtitle: 'Manage hidden channel groups',
    icon: Icons.visibility_off_outlined,
  ),

  // History
  _SettingsItem(
    section: SettingsSection.history,
    label: 'Watch history',
    subtitle: 'Viewing history and continue watching',
    icon: Icons.history,
  ),
  _SettingsItem(
    section: SettingsSection.history,
    label: 'Clear history',
    subtitle: 'Remove all viewing history',
    icon: Icons.delete_sweep_outlined,
  ),

  // Parental
  _SettingsItem(
    section: SettingsSection.parental,
    label: 'Parental controls',
    subtitle: 'Age rating locks and PIN',
    icon: Icons.child_care,
  ),
  _SettingsItem(
    section: SettingsSection.parental,
    label: 'Age rating lock',
    subtitle: 'Restrict content by age rating',
    icon: Icons.lock_outlined,
  ),

  // Admin
  _SettingsItem(
    section: SettingsSection.admin,
    label: 'Admin',
    subtitle: 'Advanced administration options',
    icon: Icons.admin_panel_settings_outlined,
  ),

  // EPG URLs
  _SettingsItem(
    section: SettingsSection.epgUrls,
    label: 'EPG URLs',
    subtitle: 'Programme guide source URLs',
    icon: Icons.link,
  ),

  // User Agent
  _SettingsItem(
    section: SettingsSection.userAgent,
    label: 'User agent',
    subtitle: 'HTTP user agent sent to servers',
    icon: Icons.http,
  ),

  // Backup
  _SettingsItem(
    section: SettingsSection.backup,
    label: 'Backup & restore',
    subtitle: 'Export or import settings',
    icon: Icons.backup_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.backup,
    label: 'Export settings',
    subtitle: 'Save a settings backup file',
    icon: Icons.upload_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.backup,
    label: 'Import settings',
    subtitle: 'Restore settings from a backup',
    icon: Icons.download_outlined,
  ),

  // Device
  _SettingsItem(
    section: SettingsSection.device,
    label: 'This device',
    subtitle: 'Device name and identifiers',
    icon: Icons.devices_outlined,
  ),

  // Cloud Sync
  _SettingsItem(
    section: SettingsSection.cloudSync,
    label: 'Cloud sync',
    subtitle: 'Sync settings across devices',
    icon: Icons.cloud_sync_outlined,
  ),

  // Cloud Storage
  _SettingsItem(
    section: SettingsSection.cloudStorage,
    label: 'Cloud storage',
    subtitle: 'Configure cloud storage backend',
    icon: Icons.cloud_outlined,
  ),

  // Experimental
  _SettingsItem(
    section: SettingsSection.experimental,
    label: 'Experimental',
    subtitle: 'Beta features — may be unstable',
    icon: Icons.science_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.experimental,
    label: 'Video upscaling',
    subtitle: 'GPU super-resolution upscaling',
    icon: Icons.hd_outlined,
  ),

  // About
  _SettingsItem(
    section: SettingsSection.about,
    label: 'About',
    subtitle: 'App version and open-source licences',
    icon: Icons.info_outline,
  ),
  _SettingsItem(
    section: SettingsSection.about,
    label: 'App version',
    subtitle: 'Current CrispyTivi version',
    icon: Icons.new_releases_outlined,
  ),
  _SettingsItem(
    section: SettingsSection.about,
    label: 'Open-source licences',
    subtitle: 'Third-party library attributions',
    icon: Icons.article_outlined,
  ),
];

// ── Delegate ──────────────────────────────────────────────────────────────────

/// A [SearchDelegate] for filtering settings sections.
///
/// Opened via [showSearch] from the Settings AppBar. Each result shows
/// the matching setting label and navigates (scrolls) to its section on tap.
///
/// [onSectionSelected] is called with the target [SettingsSection] when the
/// user taps a result. The caller is responsible for closing search and
/// scrolling to that section.
class SettingsSearchDelegate extends SearchDelegate<SettingsSection?> {
  /// Creates a settings search delegate.
  ///
  /// [onSectionSelected] is invoked when the user picks a result.
  SettingsSearchDelegate({required this.onSectionSelected});

  /// Called with the matched section when the user taps a result.
  final void Function(SettingsSection section) onSectionSelected;

  @override
  String get searchFieldLabel => 'Search settings…';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Clear',
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Filters [_kSettingsItems] against [query] and renders the list.
  Widget _buildList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final trimmed = query.trim().toLowerCase();
    final items =
        trimmed.isEmpty
            ? _kSettingsItems
            : _kSettingsItems.where((item) {
              return item.label.toLowerCase().contains(trimmed) ||
                  (item.subtitle?.toLowerCase().contains(trimmed) ?? false);
            }).toList();

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(CrispySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: CrispySpacing.md),
              Text(
                'No settings found for "$query"',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: Icon(
            item.icon ?? Icons.settings_outlined,
            color: colorScheme.primary,
          ),
          title: _HighlightedText(
            text: item.label,
            query: trimmed,
            style: textTheme.bodyLarge!,
            highlightStyle: textTheme.bodyLarge!.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle:
              item.subtitle != null
                  ? Text(
                    item.subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                  : null,
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          onTap: () {
            close(context, item.section);
            onSectionSelected(item.section);
          },
        );
      },
    );
  }
}

// ── Highlight helper ──────────────────────────────────────────────────────────

/// Renders [text] with matched substrings of [query] styled via [highlightStyle].
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightStyle,
  });

  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlightStyle;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final lower = text.toLowerCase();
    final matchStart = lower.indexOf(query);
    if (matchStart < 0) return Text(text, style: style);

    final matchEnd = matchStart + query.length;
    return Text.rich(
      TextSpan(
        children: [
          if (matchStart > 0)
            TextSpan(text: text.substring(0, matchStart), style: style),
          TextSpan(
            text: text.substring(matchStart, matchEnd),
            style: highlightStyle,
          ),
          if (matchEnd < text.length)
            TextSpan(text: text.substring(matchEnd), style: style),
        ],
      ),
    );
  }
}
