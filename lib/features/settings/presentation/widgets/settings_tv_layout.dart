import 'package:flutter/material.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import '../screens/settings_screen.dart';
import 'about_settings.dart';
import 'accessibility_settings.dart';
import 'admin_settings.dart';
import 'appearance_settings.dart';
import 'backup_settings.dart';
import 'bandwidth_settings.dart';
import 'device_settings.dart';
import 'dvr_settings.dart';
import 'experimental_settings.dart';
import 'history_settings.dart';
import 'language_settings.dart';
import 'live_tv_settings.dart';
import 'network_diagnostics_settings.dart';
import 'notification_settings.dart';
import 'parental_settings.dart';
import 'playback_settings.dart';
import 'profile_settings.dart';
import 'remote_settings.dart';
import 'screensaver_settings.dart';
import 'sources_settings.dart';
import 'storage_settings.dart';
import 'sync_settings.dart';
import '../../../cloud_sync/presentation/widgets/cloud_sync_section.dart';
import 'cloud_storage_settings.dart';

/// TV-optimized settings layout using a master-detail split.
///
/// Left panel: scrollable list of category tiles. Right panel: the
/// selected category's settings content.
class SettingsTvLayout extends StatefulWidget {
  /// Creates a settings TV layout.
  const SettingsTvLayout({
    required this.tabController,
    required this.settings,
    required this.sectionKeys,
    required this.onScrollToSection,
    super.key,
  });

  /// Tab controller for category navigation.
  final TabController tabController;

  /// Current settings state.
  final SettingsState settings;

  /// Section keys for scroll anchoring.
  final Map<SettingsSection, GlobalKey> sectionKeys;

  /// Callback to scroll to a specific section.
  final void Function(SettingsSection) onScrollToSection;

  @override
  State<SettingsTvLayout> createState() => _SettingsTvLayoutState();
}

class _SettingsTvLayoutState extends State<SettingsTvLayout> {
  SettingsSection _selectedSection = SettingsSection.profiles;

  @override
  Widget build(BuildContext context) {
    return TvMasterDetailLayout(
      masterPanel: _buildCategoryList(context),
      detailPanel: _buildDetailPane(context),
    );
  }

  Widget _buildCategoryList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final categories = <
      ({SettingsSection section, String label, IconData icon})
    >[
      (
        section: SettingsSection.profiles,
        label: 'Profiles',
        icon: Icons.people,
      ),
      (
        section: SettingsSection.appearance,
        label: 'Appearance',
        icon: Icons.palette_outlined,
      ),
      (
        section: SettingsSection.language,
        label: 'Language',
        icon: Icons.language,
      ),
      (section: SettingsSection.liveTV, label: 'Live TV', icon: Icons.live_tv),
      (
        section: SettingsSection.device,
        label: 'This Device',
        icon: Icons.devices,
      ),
      (
        section: SettingsSection.sources,
        label: 'Sources',
        icon: Icons.playlist_add,
      ),
      (
        section: SettingsSection.playback,
        label: 'Playback',
        icon: Icons.play_circle_outline,
      ),
      (
        section: SettingsSection.bandwidth,
        label: 'Data & Bandwidth',
        icon: Icons.speed,
      ),
      (
        section: SettingsSection.accessibility,
        label: 'Accessibility',
        icon: Icons.accessibility_new,
      ),
      (
        section: SettingsSection.screensaver,
        label: 'Screensaver',
        icon: Icons.nightlight_round,
      ),
      (section: SettingsSection.sync, label: 'Sync', icon: Icons.sync),
      (
        section: SettingsSection.cloudSync,
        label: 'Cloud Sync',
        icon: Icons.cloud_sync,
      ),
      (
        section: SettingsSection.cloudStorage,
        label: 'Cloud Storage',
        icon: Icons.cloud_outlined,
      ),
      (
        section: SettingsSection.backup,
        label: 'Backup & Restore',
        icon: Icons.backup,
      ),
      (
        section: SettingsSection.storage,
        label: 'Storage & Cache',
        icon: Icons.storage,
      ),
      (section: SettingsSection.history, label: 'History', icon: Icons.history),
      (
        section: SettingsSection.dvr,
        label: 'DVR & Recordings',
        icon: Icons.fiber_dvr,
      ),
      (
        section: SettingsSection.remote,
        label: 'Remote Control',
        icon: Icons.settings_remote,
      ),
      (
        section: SettingsSection.notifications,
        label: 'Notifications',
        icon: Icons.notifications_outlined,
      ),
      (
        section: SettingsSection.parental,
        label: 'Parental Controls',
        icon: Icons.child_care,
      ),
      (
        section: SettingsSection.admin,
        label: 'Admin',
        icon: Icons.admin_panel_settings,
      ),
      (section: SettingsSection.network, label: 'Network', icon: Icons.wifi),
      (
        section: SettingsSection.experimental,
        label: 'Experimental',
        icon: Icons.science,
      ),
      (
        section: SettingsSection.about,
        label: 'About',
        icon: Icons.info_outline,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.md),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = cat.section == _selectedSection;

        return ListTile(
          leading: Icon(
            cat.icon,
            color: isSelected ? cs.primary : cs.onSurfaceVariant,
          ),
          title: Text(
            cat.label,
            style: tt.bodyMedium?.copyWith(
              color: isSelected ? cs.primary : cs.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          selectedTileColor: cs.primaryContainer.withValues(alpha: 0.3),
          onTap: () => setState(() => _selectedSection = cat.section),
        );
      },
    );
  }

  Widget _buildDetailPane(BuildContext context) {
    final settings = widget.settings;

    return ListView(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      children: [
        switch (_selectedSection) {
          SettingsSection.profiles => const ProfileSettingsSection(),
          SettingsSection.appearance => const AppearanceSettingsSection(),
          SettingsSection.language => const LanguageSettingsSection(),
          SettingsSection.liveTV => LiveTvSettingsSection(settings: settings),
          SettingsSection.device => const DeviceSettingsSection(),
          SettingsSection.sources => SourcesSettingsSection(settings: settings),
          SettingsSection.epgUrls => EpgUrlSettingsSection(
            sources: settings.sources,
          ),
          SettingsSection.userAgent => UserAgentSettingsSection(
            sources: settings.sources,
          ),
          SettingsSection.playback => const PlaybackSettingsSection(),
          SettingsSection.bandwidth => BandwidthSettingsSection(
            settings: settings,
          ),
          SettingsSection.accessibility => const AccessibilitySettingsSection(),
          SettingsSection.screensaver => ScreensaverSettingsSection(
            settings: settings,
          ),
          SettingsSection.sync => SyncSettingsSection(settings: settings),
          SettingsSection.cloudSync => const CloudSyncSection(),
          SettingsSection.cloudStorage => const CloudStorageSettingsSection(),
          SettingsSection.backup => const BackupSettingsSection(),
          SettingsSection.storage => const StorageSettingsSection(),
          SettingsSection.history => const HistorySettingsSection(),
          SettingsSection.dvr => const DvrSettingsSection(),
          SettingsSection.remote => RemoteSettingsSection(
            remoteKeyMap: settings.remoteKeyMap,
          ),
          SettingsSection.notifications => NotificationSettingsSection(
            settings: settings,
          ),
          SettingsSection.contentFilter => ContentFilterSettingsSection(
            hiddenGroups: settings.hiddenGroups,
          ),
          SettingsSection.parental => const ParentalSettingsSection(),
          SettingsSection.admin => const AdminSettingsSection(),
          SettingsSection.network => const NetworkDiagnosticsTile(),
          SettingsSection.experimental => ExperimentalSettingsSection(
            upscaleEnabled: settings.config.player.upscaleEnabled,
          ),
          SettingsSection.about => AboutSettingsSection(
            appVersion: settings.config.appVersion,
          ),
        },
      ],
    );
  }
}
