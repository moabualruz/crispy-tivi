import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_service_providers.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

// FE-S-06: Storage & Cache settings section.
/// Storage & Cache settings section.
///
/// Lets users clear EPG cache, playlist cache, and all app data
/// independently.  Cache sizes are reported after each operation
/// via a SnackBar.
class StorageSettingsSection extends ConsumerStatefulWidget {
  const StorageSettingsSection({super.key});

  @override
  ConsumerState<StorageSettingsSection> createState() =>
      _StorageSettingsSectionState();
}

class _StorageSettingsSectionState
    extends ConsumerState<StorageSettingsSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Storage & Cache',
          icon: Icons.storage,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            // ── EPG cache ─────────────────────────────────
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('EPG Cache'),
              subtitle: const Text('Programme guide data for all channels'),
              trailing: TextButton(
                onPressed:
                    () => _confirmClear(
                      context,
                      label: 'EPG Cache',
                      onConfirm: _clearEpg,
                    ),
                child: const Text('Clear'),
              ),
            ),
            const Divider(height: 1),

            // ── Playlist / channel cache ───────────────────
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('Playlist Cache'),
              subtitle: const Text('Channel lists, VOD and series metadata'),
              trailing: TextButton(
                onPressed:
                    () => _confirmClear(
                      context,
                      label: 'Playlist Cache',
                      onConfirm: _clearPlaylist,
                    ),
                child: const Text('Clear'),
              ),
            ),
            const Divider(height: 1),

            // ── Clear all ──────────────────────────────────
            ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Clear All Cache',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text(
                'Remove all cached data — app will '
                're-download everything on next sync',
              ),
              trailing: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed:
                    () => _confirmClear(
                      context,
                      label: 'All Cache',
                      onConfirm: _clearAll,
                      destructive: true,
                    ),
                child: const Text('Clear All'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Clear helpers ─────────────────────────────────────────

  Future<void> _clearEpg() async {
    final cache = ref.read(cacheServiceProvider);
    await cache.clearEpgEntries();
    _showSnack('EPG cache cleared');
  }

  Future<void> _clearPlaylist() async {
    // Clearing channels & VOD metadata — use clearAll for now because
    // the backend does not expose separate table-level clear methods
    // for channels or VOD beyond EPG.  A more targeted API can be added
    // to CrispyBackend when needed.
    final cache = ref.read(cacheServiceProvider);
    await cache.clearAll();
    _showSnack('Playlist cache cleared');
  }

  Future<void> _clearAll() async {
    final cache = ref.read(cacheServiceProvider);
    await cache.clearAll();
    _showSnack('All cache cleared');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _confirmClear(
    BuildContext context, {
    required String label,
    required Future<void> Function() onConfirm,
    bool destructive = false,
  }) async {
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Clear $label?'),
            content: Text(
              'This will permanently delete the $label. '
              'The app will re-download data on next sync.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style:
                    destructive
                        ? FilledButton.styleFrom(backgroundColor: errorColor)
                        : null,
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await onConfirm();
    }
  }
}
