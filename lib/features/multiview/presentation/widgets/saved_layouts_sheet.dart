import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/multiview_session.dart';
import '../../domain/entities/saved_layout.dart';
import '../providers/multiview_providers.dart';

/// Bottom sheet listing saved multi-view layouts.
class SavedLayoutsSheet extends ConsumerWidget {
  const SavedLayoutsSheet({
    super.key,
    required this.onLoad,
    required this.onDelete,
  });

  /// Called when the user taps a layout row.
  final ValueChanged<SavedLayout> onLoad;

  /// Called when the user confirms deletion.
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLayouts = ref.watch(savedLayoutsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(CrispySpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: CrispySpacing.sm),
                  Text(
                    'Saved Layouts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.24),
            ),

            // List of saved layouts
            Expanded(
              child: asyncLayouts.when(
                data: (layouts) {
                  if (layouts.isEmpty) {
                    return Center(
                      child: Text(
                        'No saved layouts yet.\n'
                        'Save your current layout '
                        'using the save button.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: layouts.length,
                    itemBuilder: (context, index) {
                      final layout = layouts[index];
                      return SavedLayoutTile(
                        layout: layout,
                        onTap: () => onLoad(layout),
                        onDelete: () => onDelete(layout.id),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (e, _) => Center(
                      child: Text(
                        'Error loading layouts: $e',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single row in the saved-layouts list.
class SavedLayoutTile extends StatelessWidget {
  const SavedLayoutTile({
    super.key,
    required this.layout,
    required this.onTap,
    required this.onDelete,
  });

  final SavedLayout layout;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final channelCount = layout.streams.where((s) => s != null).length;
    final layoutLabel = _layoutLabel(layout.layout);
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 48,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.24),
          ),
        ),
        child: Center(
          child: Text(
            layoutLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(layout.name, style: TextStyle(color: colorScheme.onSurface)),
      subtitle: Text(
        '$channelCount '
        'channel${channelCount == 1 ? '' : 's'}',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: colorScheme.onSurfaceVariant),
        tooltip: 'Delete layout',
        onPressed: () {
          showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Delete Layout'),
                  content: Text('Delete "${layout.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
          );
        },
      ),
      onTap: onTap,
    );
  }

  String _layoutLabel(MultiViewLayout layout) {
    switch (layout) {
      case MultiViewLayout.twoByOne:
        return '2\u00d71';
      case MultiViewLayout.twoByTwo:
        return '2\u00d72';
      case MultiViewLayout.threeByThree:
        return '3\u00d73';
    }
  }
}
