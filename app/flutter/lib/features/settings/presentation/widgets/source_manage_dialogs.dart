import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/presentation/providers/duplicate_detection_service.dart';
import 'source_add_dialogs.dart' show showAddXtreamDialog;

/// Shows a dialog listing duplicate channel groups.
void showDuplicatesDialog({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final groups = ref.read(duplicateGroupsProvider);

  showDialog(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Duplicate Channels'),
          content: SizedBox(
            width: 400,
            child:
                groups.isEmpty
                    ? const Text('No duplicate channels found.')
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: CrispySpacing.sm,
                          ),
                          child: ListTile(
                            title: Text(
                              '${group.count} channels '
                              'share same stream',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              group.streamUrl.length > 50
                                  ? '${group.streamUrl.substring(0, 50)}...'
                                  : group.streamUrl,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CrispySpacing.sm,
                                vertical: CrispySpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.tertiary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                '${group.count}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
  );
}

/// Shows the dialog to open the "Add Xtream"
/// dialog.
///
/// Used by [SettingsScreen] when navigated with
/// `extra: {'action': 'addXtream'}`.
void showAddXtreamDialogFromScreen(BuildContext context, WidgetRef ref) {
  showAddXtreamDialog(
    context: context,
    ref: ref,
    isMounted: () => context.mounted,
  );
}
