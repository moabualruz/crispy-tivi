import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../data/backup_service.dart';
import 'settings_shared_widgets.dart';

/// Backup & Restore settings section.
class BackupSettingsSection extends ConsumerStatefulWidget {
  const BackupSettingsSection({super.key});

  @override
  ConsumerState<BackupSettingsSection> createState() =>
      _BackupSettingsSectionState();
}

class _BackupSettingsSectionState extends ConsumerState<BackupSettingsSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Backup & Restore',
          icon: Icons.backup,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Export to File'),
              subtitle: const Text(
                'Share backup file via system '
                'share sheet',
              ),
              trailing: const Icon(Icons.ios_share),
              onTap: () => _exportToFile(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Save to File'),
              subtitle: const Text('Save backup to a specific location'),
              trailing: const Icon(Icons.folder_open),
              onTap: () => _saveToFile(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.file_open),
              title: const Text('Import from File'),
              subtitle: const Text('Restore from a backup file'),
              trailing: const Icon(Icons.upload_file),
              onTap: () => _importFromFile(context),
            ),
            const Divider(height: 1),
            ExpansionTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Clipboard Options'),
              subtitle: const Text('Copy or paste backup data'),
              children: [
                ListTile(
                  leading: const SizedBox(width: CrispySpacing.lg),
                  title: const Text('Copy to Clipboard'),
                  trailing: const Icon(Icons.copy),
                  onTap: () => _exportBackup(context),
                ),
                ListTile(
                  leading: const SizedBox(width: CrispySpacing.lg),
                  title: const Text('Paste from Clipboard'),
                  trailing: const Icon(Icons.paste),
                  onTap: () => _importBackup(context),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  //  Backup / Restore methods
  // ════════════════════════════════════════════════════════

  Future<void> _exportBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Exporting backup…')),
      );
      final backup = ref.read(backupServiceProvider);
      final json = await backup.exportBackup();
      await Clipboard.setData(ClipboardData(text: json));

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup copied to clipboard')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Import Backup'),
            content: const Text(
              'This will merge data from your clipboard '
              'with existing data. Existing items with '
              'the same ID will be overwritten.\n\n'
              'Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import'),
              ),
            ],
          ),
    );

    if (!mounted) return;
    if (confirmed != true) return;

    final messenger =
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Importing backup…')),
      );
      final data = await Clipboard.getData('text/plain');
      if (data?.text == null || data!.text!.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
        return;
      }

      final backup = ref.read(backupServiceProvider);
      final summary = await backup.importBackup(data.text!);

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Imported: $summary')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _exportToFile(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Preparing backup file…')),
      );
      final backup = ref.read(backupServiceProvider);
      await backup.exportToFile();

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Backup shared')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _saveToFile(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Preparing backup file…')),
      );
      final backup = ref.read(backupServiceProvider);
      final path = await backup.saveToFile();

      if (!mounted) return;
      if (path != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Backup saved to $path')),
        );
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Save cancelled')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _importFromFile(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Import Backup'),
            content: const Text(
              'This will merge data from the backup file '
              'with existing data. Existing items with '
              'the same ID will be overwritten.\n\n'
              'Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Select File'),
              ),
            ],
          ),
    );

    if (!mounted) return;
    if (confirmed != true) return;

    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Select a backup file…')),
      );
      final backup = ref.read(backupServiceProvider);
      final summary = await backup.importFromFile();

      if (!mounted) return;
      if (summary != null) {
        messenger.showSnackBar(SnackBar(content: Text('Imported: $summary')));
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Import cancelled')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}

// FE-S-02 ─────────────────────────────────────────────────────────────────────

/// Settings-specific Import / Export tile.
///
/// FE-S-02: Serialises the current [SettingsState] preferences to a compact
/// JSON, writes it to clipboard or shares via the system share sheet.
/// Import parses a JSON from clipboard and applies each recognised key
/// back to [SettingsNotifier].
///
/// Only portable, non-sensitive preferences are included (sort modes,
/// notification flags, UI toggles). Source credentials are excluded.
class SettingsImportExportSection extends ConsumerStatefulWidget {
  const SettingsImportExportSection({super.key});

  @override
  ConsumerState<SettingsImportExportSection> createState() =>
      _SettingsImportExportSectionState();
}

class _SettingsImportExportSectionState
    extends ConsumerState<SettingsImportExportSection> {
  // ── Export ────────────────────────────────────────────────────────────

  /// FE-S-02: Serialise settings to JSON and share / copy to clipboard.
  Future<void> _exportSettings(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final settingsAsync = ref.read(settingsNotifierProvider);
    final settings = settingsAsync.value;
    if (settings == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Settings not yet loaded')),
      );
      return;
    }

    final exportMap = <String, dynamic>{
      // FE-S-02: schema version for forward compatibility.
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'preferences': {
        'defaultScreen': settings.defaultScreen,
        'autoResumeChannel': settings.autoResumeChannel,
        'autoplayNextEpisode': settings.autoplayNextEpisode,
        'notificationsEnabled': settings.notificationsEnabled,
        'notifyRecordingComplete': settings.notifyRecordingComplete,
        'notifyNewEpisode': settings.notifyNewEpisode,
        'notifyLiveEvent': settings.notifyLiveEvent,
        'qualityCap': settings.qualityCap.name,
        'dataSavingMode': settings.dataSavingMode,
        'cellularDataLimitEnabled': settings.cellularDataLimitEnabled,
        'historyRecordingPaused': settings.historyRecordingPaused,
      },
    };

    final jsonText = const JsonEncoder.withIndent('  ').convert(exportMap);
    await Clipboard.setData(ClipboardData(text: jsonText));

    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Settings exported to clipboard'),
        duration: CrispyAnimation.toastDuration,
      ),
    );
  }

  // ── Import ────────────────────────────────────────────────────────────

  /// FE-S-02: Reads JSON from clipboard, validates, applies to settings.
  Future<void> _importSettings(BuildContext context) async {
    // Confirmation dialog — overwrite warning.
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Import Settings'),
            content: const Text(
              'This will overwrite your current preferences with the '
              'settings from your clipboard.\n\nContinue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import'),
              ),
            ],
          ),
    );

    if (!context.mounted) return;
    if (confirmed != true) return;

    final messenger =
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context);

    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text;
      if (text == null || text.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
        return;
      }

      // Parse and validate.
      final decoded = json.decode(text) as Map<String, dynamic>?;
      if (decoded == null || decoded['preferences'] == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Invalid settings file')),
        );
        return;
      }

      final prefs = decoded['preferences'] as Map<String, dynamic>;
      final notifier = ref.read(settingsNotifierProvider.notifier);

      // Apply each recognised preference.
      if (prefs['defaultScreen'] is String) {
        await notifier.setDefaultScreen(prefs['defaultScreen'] as String);
      }
      if (prefs['autoResumeChannel'] is bool) {
        await notifier.setAutoResumeChannel(prefs['autoResumeChannel'] as bool);
      }
      if (prefs['autoplayNextEpisode'] is bool) {
        await notifier.setAutoplayNextEpisode(
          prefs['autoplayNextEpisode'] as bool,
        );
      }
      if (prefs['notificationsEnabled'] is bool) {
        await notifier.setNotificationsEnabled(
          prefs['notificationsEnabled'] as bool,
        );
      }
      if (prefs['notifyRecordingComplete'] is bool) {
        await notifier.setNotifyRecordingComplete(
          prefs['notifyRecordingComplete'] as bool,
        );
      }
      if (prefs['notifyNewEpisode'] is bool) {
        await notifier.setNotifyNewEpisode(prefs['notifyNewEpisode'] as bool);
      }
      if (prefs['notifyLiveEvent'] is bool) {
        await notifier.setNotifyLiveEvent(prefs['notifyLiveEvent'] as bool);
      }
      if (prefs['dataSavingMode'] is bool) {
        await notifier.setDataSavingMode(prefs['dataSavingMode'] as bool);
      }
      if (prefs['cellularDataLimitEnabled'] is bool) {
        await notifier.setCellularDataLimitEnabled(
          prefs['cellularDataLimitEnabled'] as bool,
        );
      }

      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Settings imported successfully'),
          duration: CrispyAnimation.toastDuration,
        ),
      );
    } on FormatException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to parse settings JSON')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Settings Import / Export',
          icon: Icons.settings_backup_restore,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Export Settings'),
              subtitle: const Text('Copy app preferences to clipboard as JSON'),
              trailing: const Icon(Icons.copy),
              onTap: () => _exportSettings(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Import Settings'),
              subtitle: const Text(
                'Paste preferences from clipboard — overwrites current',
              ),
              trailing: const Icon(Icons.paste),
              onTap: () => _importSettings(context),
            ),
          ],
        ),
      ],
    );
  }
}
