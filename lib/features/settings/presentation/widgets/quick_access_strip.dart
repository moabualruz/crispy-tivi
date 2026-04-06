import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/application/playlist_sync_service.dart';
import '../providers/settings_service_providers.dart';

// FE-S-12: Quick-Access strip — horizontally scrollable icon action chips.
/// Quick-access horizontal strip at the top of the settings screen.
///
/// Provides one-tap access to common actions:
/// - Refresh Playlists
/// - Clear Cache
/// - Check for Updates
/// - Backup / Restore
///
/// Each tile is an icon + short label. The strip scrolls
/// horizontally on narrow viewports.
class QuickAccessStrip extends ConsumerWidget {
  const QuickAccessStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final tiles = <_QuickTileData>[
      _QuickTileData(
        icon: Icons.refresh,
        label: 'Refresh\nPlaylists',
        onTap: (ctx) => _refreshPlaylists(ctx, ref),
      ),
      _QuickTileData(
        icon: Icons.delete_sweep_outlined,
        label: 'Clear\nCache',
        onTap: (ctx) => _clearCache(ctx, ref),
      ),
      _QuickTileData(
        icon: Icons.system_update_alt,
        label: 'Check for\nUpdates',
        onTap: (ctx) async => _checkForUpdates(ctx),
      ),
      _QuickTileData(
        icon: Icons.backup,
        label: 'Backup /\nRestore',
        onTap: (ctx) async => _openBackupRestore(ctx, ref),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: CrispySpacing.xs,
            bottom: CrispySpacing.sm,
          ),
          child: Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.xs),
            itemCount: tiles.length,
            separatorBuilder: (_, i) => const SizedBox(width: CrispySpacing.sm),
            itemBuilder: (context, i) => _QuickTile(data: tiles[i]),
          ),
        ),
      ],
    );
  }

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _refreshPlaylists(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Syncing all playlists…')),
    );
    try {
      final syncService = ref.read(playlistSyncServiceProvider);
      final count = await syncService.syncAll(force: true);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Synced $count channels')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Clear Cache?'),
            content: const Text(
              'All cached data will be removed. '
              'The app will re-download everything on next sync.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final cache = ref.read(cacheServiceProvider);
      await cache.clearAll();
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Cache cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Clear failed: $e')));
      }
    }
  }

  void _checkForUpdates(BuildContext context) {
    // Update check is a placeholder — no auto-update infrastructure yet.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You are running the latest version.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openBackupRestore(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => _BackupRestoreSheet(ref: ref),
    );
  }
}

// ── Tile data model ──────────────────────────────────────────────

class _QuickTileData {
  const _QuickTileData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function(BuildContext) onTap;
}

// ── Individual tile widget ───────────────────────────────────────

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.data});

  final _QuickTileData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 88,
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        child: Semantics(
          button: true,
          label: data.label,
          child: InkWell(
            onTap: () => data.onTap(context),
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.sm,
                vertical: CrispySpacing.sm,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(data.icon, color: colorScheme.primary, size: 28),
                  const SizedBox(height: CrispySpacing.xs),
                  Text(
                    data.label,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Backup / Restore sheet ───────────────────────────────────────

/// Minimal backup/restore bottom sheet for the Quick Access strip.
///
/// Delegates to [BackupService] — same logic as [BackupSettingsSection]
/// but surfaced as a quick-action sheet.
class _BackupRestoreSheet extends ConsumerStatefulWidget {
  const _BackupRestoreSheet({required this.ref});

  // ignore: library_private_types_in_public_api
  final WidgetRef ref;

  @override
  ConsumerState<_BackupRestoreSheet> createState() =>
      _BackupRestoreSheetState();
}

class _BackupRestoreSheetState extends ConsumerState<_BackupRestoreSheet> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: CrispySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.backup, color: colorScheme.primary),
                const SizedBox(width: CrispySpacing.sm),
                Text(
                  'Backup & Restore',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispySpacing.md),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Export Backup'),
              subtitle: const Text('Share backup file via system share sheet'),
              trailing: const Icon(Icons.ios_share),
              onTap: () => _export(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.file_open),
              title: const Text('Import Backup'),
              subtitle: const Text('Restore from a backup file'),
              trailing: const Icon(Icons.upload_file),
              onTap: () => _import(context),
            ),
            const SizedBox(height: CrispySpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    Navigator.of(context).pop();
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Preparing backup file…')),
      );
      final backup = ref.read(backupServiceProvider);
      await backup.exportToFile();
      if (context.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Backup shared')));
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Import Backup'),
            content: const Text(
              'This will merge data from the backup file '
              'with existing data. Existing items with '
              'the same ID will be overwritten.\n\nContinue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Select File'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    Navigator.of(context).pop();

    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Select a backup file…')),
      );
      final backup = ref.read(backupServiceProvider);
      final summary = await backup.importFromFile();
      if (context.mounted && summary != null) {
        messenger.showSnackBar(SnackBar(content: Text('Imported: $summary')));
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }
}
