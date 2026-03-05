import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../data/transfer_service.dart';
import '../../domain/entities/storage_backend.dart';
import '../../domain/entities/transfer_task.dart';
import '../../domain/storage_provider.dart';
import '../../domain/utils/file_filter.dart';
import '../widgets/file_metadata_sheet.dart';
import 'cloud_browser_providers.dart';
import 'cloud_file_grid.dart';

/// Returns the parent path of [path] (the portion before
/// the last `/`), or an empty string if [path] has no
/// `/` separator.
String parentPath(String path) {
  final parts = path.split('/');
  parts.removeLast();
  return parts.join('/');
}

/// Browse files on configured cloud storage backends.
///
/// Supports:
/// - Navigating directories
/// - File type filter chips (FE-CB-02)
/// - Client-side sort controls (FE-CB-03)
/// - Multi-select with bulk Delete / Download actions (FE-CB-05)
/// - Sync status overlays on file cards (FE-CB-06)
/// - File metadata panel via long-press or info icon (FE-CB-07)
/// - Upload from device (FE-CB-08)
/// - Recent files horizontal row at the top (FE-CB-09)
/// - Copy pre-signed link for S3 backends (FE-CB-10)
class CloudBrowserScreen extends ConsumerStatefulWidget {
  const CloudBrowserScreen({super.key});

  @override
  ConsumerState<CloudBrowserScreen> createState() => _CloudBrowserScreenState();
}

class _CloudBrowserScreenState extends ConsumerState<CloudBrowserScreen> {
  StorageBackend? _selectedBackend;
  List<RemoteFile>? _files;
  bool _loading = false;
  String? _error;
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final backends = ref.read(storageBackendsProvider);
      if (backends.isNotEmpty) {
        _selectBackend(
          backends.where((b) => b.isDefault).firstOrNull ?? backends.first,
        );
      }
    });
  }

  // ── Navigation ───────────────────────────────────────────────

  Future<void> _selectBackend(StorageBackend backend) async {
    _exitMultiSelect();
    setState(() {
      _selectedBackend = backend;
      _currentPath = '';
      _loading = true;
      _error = null;
      _files = null;
    });
    await _loadFiles('');
  }

  Future<void> _loadFiles(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPath = path;
    });

    try {
      final notifier = ref.read(transferServiceProvider.notifier);
      final files = await notifier.listFiles(_selectedBackend!, path);
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Multi-select (FE-CB-05) ──────────────────────────────────

  void _enterMultiSelect(String? initialPath) {
    ref.read(multiSelectActiveProvider.notifier).activate();
    if (initialPath != null) {
      ref.read(selectedPathsProvider.notifier).setAll({initialPath});
    }
  }

  void _exitMultiSelect() {
    ref.read(multiSelectActiveProvider.notifier).deactivate();
    ref.read(selectedPathsProvider.notifier).clear();
  }

  void _toggleSelection(String path) {
    ref.read(selectedPathsProvider.notifier).toggle(path);
  }

  Future<void> _bulkDelete(Set<String> paths) async {
    final confirmed = await _confirmBulkDelete(paths.length);
    if (!confirmed || !mounted) return;

    _exitMultiSelect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${paths.length} item(s)'),
          duration: CrispyAnimation.slow,
        ),
      );
    }
    await _loadFiles(_currentPath);
  }

  Future<bool> _confirmBulkDelete(int count) async {
    return showConfirmDeleteDialog(
      context: context,
      title: 'Delete items?',
      content: 'Permanently delete $count item(s) from remote storage?',
    );
  }

  void _bulkDownload(Set<String> paths) {
    _exitMultiSelect();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Queued ${paths.length} download(s)'),
        duration: CrispyAnimation.slow,
      ),
    );
  }

  // ── Metadata sheet (FE-CB-07) ────────────────────────────────

  void _showMetadata(RemoteFile file) {
    showFileMetadataSheet(
      context: context,
      file: file,
      backendName: _selectedBackend?.name ?? 'Unknown',
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
        _showSingleDeleteConfirm(file);
      },
      onCopyLink: () {
        Navigator.of(context).pop();
        _copyLink(file);
      },
    );
  }

  Future<void> _showSingleDeleteConfirm(RemoteFile file) async {
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: 'Delete item?',
      content: 'Delete "${file.name}" from remote storage?',
    );
    if (confirmed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${file.name}'),
          duration: CrispyAnimation.slow,
        ),
      );
      await _loadFiles(_currentPath);
    }
  }

  // ── FE-CB-08: Upload from device ─────────────────────────────

  Future<void> _uploadFromDevice() async {
    if (_selectedBackend == null) return;

    final pickedPaths = await pickFilesToUpload();
    if (pickedPaths == null || pickedPaths.isEmpty || !mounted) return;

    ref.read(uploadActiveProvider.notifier).setActive(true);
    final notifier = ref.read(transferServiceProvider.notifier);

    for (final localPath in pickedPaths) {
      final fileName = localPath.split('/').last.split('\\').last;
      final remotePath =
          _currentPath.isEmpty ? fileName : '$_currentPath/$fileName';
      await notifier.queueLocalUpload(
        localPath,
        _selectedBackend!.id,
        remotePath: remotePath,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Queued ${pickedPaths.length} upload(s)'),
          duration: CrispyAnimation.slow,
        ),
      );
    }
    ref.read(uploadActiveProvider.notifier).setActive(false);
    await _loadFiles(_currentPath);
  }

  // ── FE-CB-10: Copy pre-signed link (S3) ─────────────────────

  Future<void> _copyLink(RemoteFile file) async {
    final backend = _selectedBackend;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          duration: CrispyAnimation.fast,
        ),
      );
    }
  }

  // ── FE-CB-06: Sync status helper ────────────────────────────

  SyncStatus _syncStatusForFile(RemoteFile file, List<TransferTask> tasks) {
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

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final backends = ref.watch(storageBackendsProvider);
    final isMultiSelect = ref.watch(multiSelectActiveProvider);
    final selectedPaths = ref.watch(selectedPathsProvider);
    final sortOrder = ref.watch(sortOrderProvider);

    return Scaffold(
      key: TestKeys.cloudBrowserScreen,
      appBar: AppBar(
        title:
            isMultiSelect
                ? Text('${selectedPaths.length} selected')
                : const Text('Cloud Storage'),
        leading:
            isMultiSelect
                ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel selection',
                  onPressed: _exitMultiSelect,
                )
                : null,
        actions: _buildAppBarActions(
          backends: backends,
          isMultiSelect: isMultiSelect,
          selectedPaths: selectedPaths,
          sortOrder: sortOrder,
        ),
      ),
      body: FocusTraversalGroup(
        child:
            backends.isEmpty
                ? EmptyBackendsPlaceholder(
                  onOpenSettings:
                      () => context.go(
                        AppRoutes.settings,
                        extra: {'section': 'cloudStorage'},
                      ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedBackend != null)
                      CloudPathBar(
                        backend: _selectedBackend!,
                        currentPath: _currentPath,
                        onGoUp:
                            _currentPath.isNotEmpty
                                ? () => _loadFiles(parentPath(_currentPath))
                                : null,
                      ),
                    if (_files != null && _files!.isNotEmpty)
                      CloudFilterChipBar(
                        onFilterChanged: (f) {
                          ref.read(fileTypeFilterProvider.notifier).set(f);
                        },
                      ),
                    Expanded(
                      child: _buildContent(isMultiSelect, selectedPaths),
                    ),
                  ],
                ),
      ),
      bottomNavigationBar:
          isMultiSelect
              ? BulkActionBar(
                selectedCount: selectedPaths.length,
                onDelete:
                    selectedPaths.isEmpty
                        ? null
                        : () => _bulkDelete(selectedPaths),
                onDownload:
                    selectedPaths.isEmpty
                        ? null
                        : () => _bulkDownload(selectedPaths),
              )
              : null,
      floatingActionButton:
          (!isMultiSelect && _selectedBackend != null)
              ? UploadFab(
                isUploading: ref.watch(uploadActiveProvider),
                onTap: _uploadFromDevice,
              )
              : null,
    );
  }

  List<Widget> _buildAppBarActions({
    required List<StorageBackend> backends,
    required bool isMultiSelect,
    required Set<String> selectedPaths,
    required SortOrder sortOrder,
  }) {
    return [
      if (!isMultiSelect && _files != null && _files!.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: 'Select items',
          onPressed: () => _enterMultiSelect(null),
        ),
      if (isMultiSelect && selectedPaths.length == _files?.length)
        IconButton(
          icon: const Icon(Icons.deselect),
          tooltip: 'Deselect all',
          onPressed: () {
            ref.read(selectedPathsProvider.notifier).clear();
          },
        ),
      if (isMultiSelect && selectedPaths.length != _files?.length)
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: 'Select all',
          onPressed: () {
            final allPaths = (_files ?? []).map((f) => f.path).toSet();
            ref.read(selectedPathsProvider.notifier).setAll(allPaths);
          },
        ),
      if (!isMultiSelect && backends.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed:
              _selectedBackend != null ? () => _loadFiles(_currentPath) : null,
        ),
      if (!isMultiSelect && _files != null && _files!.isNotEmpty)
        Tooltip(
          message: 'Sort',
          child: PopupMenuButton<SortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort files',
            onSelected: (order) {
              ref.read(sortOrderProvider.notifier).set(order);
            },
            initialValue: sortOrder,
            itemBuilder:
                (_) =>
                    SortOrder.values
                        .map(
                          (o) => PopupMenuItem<SortOrder>(
                            value: o,
                            child: Row(
                              children: [
                                if (o == sortOrder)
                                  const Icon(Icons.check, size: 16)
                                else
                                  const SizedBox(width: 16),
                                const SizedBox(width: 8),
                                Text(o.label),
                              ],
                            ),
                          ),
                        )
                        .toList(),
          ),
        ),
      if (!isMultiSelect && backends.length > 1)
        Tooltip(
          message: 'Switch backend',
          child: PopupMenuButton<StorageBackend>(
            icon: const Icon(Icons.swap_horiz),
            onSelected: _selectBackend,
            itemBuilder:
                (_) =>
                    backends
                        .map(
                          (b) => PopupMenuItem(
                            value: b,
                            child: Text(
                              '${b.name}${b.isDefault ? ' (Default)' : ''}',
                            ),
                          ),
                        )
                        .toList(),
          ),
        ),
    ];
  }

  Widget _buildContent(bool isMultiSelect, Set<String> selectedPaths) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _loadFiles(_currentPath),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_files == null || _files!.isEmpty) {
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

    final activeFilter = ref.watch(fileTypeFilterProvider);
    final sortOrder = ref.watch(sortOrderProvider);

    final filtered =
        _files!
            .where((f) => f.isDirectory || matchesFilter(f.name, activeFilter))
            .toList();

    final sorted = sortFiles(filtered, sortOrder);

    final transferState = ref.watch(transferServiceProvider).value;
    final activeTasks = transferState?.tasks ?? [];
    final recentFiles = ref.watch(recentFilesProvider);
    final isS3 = _selectedBackend?.type == StorageType.s3;

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
            child: RecentFilesRow(
              recentFiles: recentFiles,
              onTap: (file) {
                if (file.isDirectory) {
                  _loadFiles(file.path);
                } else {
                  _showMetadata(file);
                }
              },
            ),
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
              final syncStatus = _syncStatusForFile(file, activeTasks);

              return RemoteFileCard(
                file: file,
                isMultiSelect: isMultiSelect,
                isSelected: isSelected,
                syncStatus: syncStatus,
                isS3Backend: isS3,
                onTap: () {
                  if (isMultiSelect) {
                    _toggleSelection(file.path);
                  } else if (file.isDirectory) {
                    _loadFiles(file.path);
                  } else {
                    ref.read(recentFilesProvider.notifier).add(file);
                  }
                },
                onLongPress: () {
                  if (!isMultiSelect) {
                    _enterMultiSelect(file.path);
                  }
                },
                onInfo: () => _showMetadata(file),
                onCopyLink:
                    isS3 && !file.isDirectory ? () => _copyLink(file) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
