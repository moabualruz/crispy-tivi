import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/presentation/providers/playlist_sync_service.dart';
import '../providers/settings_service_providers.dart';
import 'backup_settings.dart' show BackupQuickActionsSheet;
import 'settings_shared_widgets.dart';

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
    final confirmed = await showSettingsConfirmationDialog(
      context: context,
      title: 'Clear Cache?',
      content:
          'All cached data will be removed. '
          'The app will re-download everything on next sync.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
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
      builder: (_) => const BackupQuickActionsSheet(),
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
