import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/loading_state_widget.dart';
import '../../domain/entities/transfer_task.dart';
import '../../domain/storage_provider.dart';
import '../screens/cloud_browser_providers.dart';
import '../screens/cloud_file_grid.dart';

/// The scrollable content area for [CloudBrowserScreen].
///
/// Renders the appropriate state: loading, error, empty-files,
/// filter-empty, or the sortable file list.
class CloudBrowserBody extends ConsumerWidget {
  const CloudBrowserBody({
    required this.loading,
    required this.sorting,
    required this.error,
    required this.files,
    required this.sortedFiles,
    required this.isMultiSelect,
    required this.selectedPaths,
    required this.activeTasks,
    required this.recentFiles,
    required this.isS3Backend,
    required this.onRetry,
    required this.onTapFile,
    required this.onLongPressFile,
    required this.onInfoFile,
    required this.onCopyLink,
    required this.onToggleSelection,
    required this.onEnterMultiSelect,
    required this.syncStatusForFile,
    super.key,
  });

  final bool loading;
  final bool sorting;
  final String? error;
  final List<RemoteFile>? files;
  final List<RemoteFile>? sortedFiles;
  final bool isMultiSelect;
  final Set<String> selectedPaths;
  final List<TransferTask> activeTasks;
  final List<RemoteFile> recentFiles;
  final bool isS3Backend;

  final VoidCallback onRetry;
  final void Function(RemoteFile) onTapFile;
  final void Function(RemoteFile) onLongPressFile;
  final void Function(RemoteFile) onInfoFile;
  final void Function(RemoteFile)? onCopyLink;
  final void Function(String) onToggleSelection;
  final void Function(String?) onEnterMultiSelect;
  final SyncStatus Function(RemoteFile, List<TransferTask>) syncStatusForFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) {
      return const LoadingStateWidget();
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(error!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (files == null || files!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            const Text('No files found'),
          ],
        ),
      );
    }

    // Show spinner while the async filter+sort is in progress.
    if (sorting || sortedFiles == null) {
      return const LoadingStateWidget();
    }

    final sorted = sortedFiles!;

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            const Text('No files match the current filter'),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (recentFiles.isNotEmpty)
          SliverToBoxAdapter(
            child: RecentFilesRow(recentFiles: recentFiles, onTap: onTapFile),
          ),
        SliverPadding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: isMultiSelect ? kBulkBarHeight + 16 : 16,
          ),
          sliver: SliverList.builder(
            itemCount: sorted.length,
            itemBuilder: (_, index) {
              final file = sorted[index];
              final isSelected = selectedPaths.contains(file.path);
              final syncStatus = syncStatusForFile(file, activeTasks);

              return RemoteFileCard(
                file: file,
                isMultiSelect: isMultiSelect,
                isSelected: isSelected,
                syncStatus: syncStatus,
                isS3Backend: isS3Backend,
                onTap: () {
                  if (isMultiSelect) {
                    onToggleSelection(file.path);
                  } else {
                    onTapFile(file);
                  }
                },
                onLongPress: () {
                  if (!isMultiSelect) {
                    onEnterMultiSelect(file.path);
                  }
                },
                onInfo: () => onInfoFile(file),
                onCopyLink:
                    isS3Backend && !file.isDirectory
                        ? () => onCopyLink?.call(file)
                        : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
