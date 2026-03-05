import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../dvr/data/transfer_service.dart';
import '../../../dvr/domain/entities/storage_backend.dart';
import '../../../dvr/presentation/widgets/storage_config_dialog.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Cloud storage backend management section.
class CloudStorageSettingsSection extends ConsumerWidget {
  const CloudStorageSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferState = ref.watch(transferServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Cloud Storage',
          icon: Icons.cloud_upload,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        transferState.when(
          loading:
              () => const SettingsCard(
                children: [
                  ListTile(
                    leading: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Loading...'),
                  ),
                ],
              ),
          error:
              (e, _) => SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.error),
                    title: Text('Error: $e'),
                  ),
                ],
              ),
          data: (state) {
            final backends = state.backends;
            final colorScheme = Theme.of(context).colorScheme;

            return SettingsCard(
              children: [
                if (backends.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.cloud_off),
                    title: Text('No storage backends'),
                    subtitle: Text(
                      'Add a cloud storage to '
                      'upload recordings',
                    ),
                  )
                else
                  ...backends.map((b) {
                    return ListTile(
                      leading: Icon(
                        _iconForType(b.type),
                        color: colorScheme.primary,
                      ),
                      title: Text(b.name),
                      subtitle: Text(
                        b.type.label + (b.isDefault ? ' (Default)' : ''),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Storage options',
                        onSelected:
                            (action) =>
                                _onBackendAction(context, ref, b, action),
                        itemBuilder:
                            (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'test',
                                child: Text('Test Connection'),
                              ),
                              if (!b.isDefault)
                                const PopupMenuItem(
                                  value: 'default',
                                  child: Text('Set as Default'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                      ),
                    );
                  }),

                const Divider(height: 1),

                // Add button.
                ListTile(
                  leading: Icon(Icons.add_circle, color: colorScheme.primary),
                  title: const Text('Add Storage Backend'),
                  onTap: () => _showAddDialog(context, ref),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  IconData _iconForType(StorageType type) {
    switch (type) {
      case StorageType.local:
        return Icons.folder;
      case StorageType.s3:
        return Icons.cloud;
      case StorageType.webdav:
        return Icons.language;
      case StorageType.smb:
        return Icons.dns;
      case StorageType.googleDrive:
        return Icons.add_to_drive;
      case StorageType.ftp:
        return Icons.terminal;
    }
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final backend = await showDialog<StorageBackend>(
      context: context,
      builder: (_) => const StorageConfigDialog(),
    );
    if (backend == null) return;

    await ref.read(transferServiceProvider.notifier).saveBackend(backend);
  }

  Future<void> _onBackendAction(
    BuildContext context,
    WidgetRef ref,
    StorageBackend backend,
    String action,
  ) async {
    final notifier = ref.read(transferServiceProvider.notifier);

    switch (action) {
      case 'edit':
        final updated = await showDialog<StorageBackend>(
          context: context,
          builder: (_) => StorageConfigDialog(backend: backend),
        );
        if (updated != null) {
          await notifier.saveBackend(updated);
        }
      case 'test':
        final ok = await notifier.testConnection(backend);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Connection successful!' : 'Connection failed'),
          ),
        );
      case 'default':
        await notifier.setDefaultBackend(backend.id);
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Delete Backend'),
                content: Text('Remove "${backend.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        );
        if (confirm == true) {
          await notifier.deleteBackend(backend.id);
        }
    }
  }
}
