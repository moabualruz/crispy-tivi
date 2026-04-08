import 'package:flutter/material.dart';

/// Shows a confirmation dialog for destructive delete actions.
///
/// Returns `true` if the user confirmed deletion, `false` or `null` if they
/// cancelled. The delete button is styled with [ColorScheme.error] /
/// [ColorScheme.onError].
///
/// Parameters:
/// - [title] — dialog headline (e.g. "Delete recording?").
/// - [content] — body text describing what will be deleted.
/// - [cancelLabel] — label for the cancel button (default: "Cancel").
/// - [deleteLabel] — label for the confirm button (default: "Delete").
///
/// Usage:
/// ```dart
/// final confirmed = await showConfirmDeleteDialog(
///   context: context,
///   title: 'Delete item?',
///   content: 'This cannot be undone.',
/// );
/// if (confirmed) { ... }
/// ```
Future<bool> showConfirmDeleteDialog({
  required BuildContext context,
  required String title,
  required String content,
  String cancelLabel = 'Cancel',
  String deleteLabel = 'Delete',
}) async {
  return await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(cancelLabel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    foregroundColor: Theme.of(ctx).colorScheme.onError,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(deleteLabel),
                ),
              ],
            ),
      ) ??
      false;
}
