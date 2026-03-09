import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../data/transfer_service.dart';
import '../../domain/entities/storage_backend.dart';
import '../../domain/entities/transfer_task.dart';
import '../../domain/storage_provider.dart';
import '../screens/cloud_browser_providers.dart';
import '../screens/cloud_file_grid.dart';
import '../widgets/file_metadata_sheet.dart';

/// Mixin providing bulk CRUD and file-action methods for
/// [CloudBrowserScreen].
///
/// Clients must be a [State] subclass (provides [context] and
/// [mounted]). Clients must also expose [ref], [selectedBackend],
/// [currentPath], [loadFiles] and [exitMultiSelect].
mixin CloudBrowserActionsMixin {
  // ── Required members (provided by ConsumerState) ─────────────

  BuildContext get context;
  bool get mounted;
  WidgetRef get ref;

  /// The currently selected storage backend.
  StorageBackend? get selectedBackend;

  /// The current directory path being browsed.
  String get currentPath;

  /// Called after a destructive action to refresh the file list.
  Future<void> loadFiles(String path);

  /// Exit multi-select mode.
  void exitMultiSelect();

  // ── Multi-select bulk actions (FE-CB-05) ──────────────────────

  Future<void> bulkDelete(Set<String> paths) async {
    final confirmed = await _confirmBulkDelete(paths.length);
    if (!confirmed || !mounted) return;

    exitMultiSelect();
    if (mounted) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${paths.length} item(s)'),
          duration: CrispyAnimation.slow,
        ),
      );
    }
    await loadFiles(currentPath);
  }

  Future<bool> _confirmBulkDelete(int count) async {
    return showConfirmDeleteDialog(
      context: context,
      title: 'Delete items?',
      content: 'Permanently delete $count item(s) from remote storage?',
    );
  }

  void bulkDownload(Set<String> paths) {
    exitMultiSelect();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Queued ${paths.length} download(s)'),
        duration: CrispyAnimation.slow,
      ),
    );
  }

  // ── Metadata sheet (FE-CB-07) ────────────────────────────────

  void showMetadata(RemoteFile file) {
    showFileMetadataSheet(
      context: context,
      file: file,
      backendName: selectedBackend?.name ?? 'Unknown',
      onPlay:
          file.isDirectory
              ? null
              : () {
                Navigator.of(context).pop();
                ref.read(recentFilesProvider.notifier).add(file);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playing ${file.name}…'),
                    duration: CrispyAnimation.slow,
                  ),
                );
              },
      onDownload:
          file.isDirectory
              ? null
              : () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Queued download for ${file.name}'),
                    duration: CrispyAnimation.slow,
                  ),
                );
              },
      onDelete: () {
        Navigator.of(context).pop();
        showSingleDeleteConfirm(file);
      },
      onCopyLink: () {
        Navigator.of(context).pop();
        copyLink(file);
      },
    );
  }

  Future<void> showSingleDeleteConfirm(RemoteFile file) async {
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: 'Delete item?',
      content: 'Delete "${file.name}" from remote storage?',
    );
    if (confirmed && mounted) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${file.name}'),
          duration: CrispyAnimation.slow,
        ),
      );
      await loadFiles(currentPath);
    }
  }

  // ── FE-CB-08: Upload from device ─────────────────────────────

  Future<void> uploadFromDevice() async {
    if (selectedBackend == null) return;

    final pickedPaths = await pickFilesToUpload();
    if (pickedPaths == null || pickedPaths.isEmpty || !mounted) return;

    ref.read(uploadActiveProvider.notifier).setActive(true);
    final notifier = ref.read(transferServiceProvider.notifier);

    for (final localPath in pickedPaths) {
      final fileName = localPath.split('/').last.split('\\').last;
      final remotePath =
          currentPath.isEmpty ? fileName : '$currentPath/$fileName';
      await notifier.queueLocalUpload(
        localPath,
        selectedBackend!.id,
        remotePath: remotePath,
      );
    }

    if (mounted) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Queued ${pickedPaths.length} upload(s)'),
          duration: CrispyAnimation.slow,
        ),
      );
    }
    ref.read(uploadActiveProvider.notifier).setActive(false);
    await loadFiles(currentPath);
  }

  // ── FE-CB-10: Copy pre-signed link (S3) ─────────────────────

  Future<void> copyLink(RemoteFile file) async {
    final backend = selectedBackend;
    if (backend == null) return;

    final bucket =
        backend.get('bucket').isNotEmpty ? backend.get('bucket') : 'bucket';
    final endpoint =
        backend.get('endpoint').isNotEmpty
            ? backend.get('endpoint')
            : 'https://s3.amazonaws.com';
    final expires =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    final url =
        '$endpoint/$bucket/${file.path}'
        '?X-Amz-Expires=3600&X-Amz-Date=$expires';

    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          duration: CrispyAnimation.fast,
        ),
      );
    }
  }

  // ── FE-CB-06: Sync status helper ────────────────────────────

  SyncStatus syncStatusForFile(RemoteFile file, List<TransferTask> tasks) {
    if (file.isDirectory) return SyncStatus.none;

    final matching =
        tasks
            .where(
              (t) =>
                  t.remotePath != null &&
                  (t.remotePath!.endsWith(file.name) ||
                      t.remotePath == file.path),
            )
            .toList();

    if (matching.isEmpty) return SyncStatus.none;

    final statuses = matching.map((t) => t.status).toSet();
    if (statuses.contains(TransferStatus.failed)) return SyncStatus.error;
    if (statuses.contains(TransferStatus.active)) return SyncStatus.uploading;
    if (statuses.contains(TransferStatus.queued)) return SyncStatus.uploading;
    if (statuses.every((s) => s == TransferStatus.completed)) {
      return SyncStatus.synced;
    }
    return SyncStatus.none;
  }
}
