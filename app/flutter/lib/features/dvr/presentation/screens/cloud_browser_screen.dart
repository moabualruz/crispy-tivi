import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/widgets/screen_template.dart';
import '../providers/dvr_providers.dart';
import '../../domain/entities/storage_backend.dart';
import '../../domain/storage_provider.dart';
import '../../domain/utils/file_filter.dart';
import '../widgets/cloud_browser_actions_mixin.dart';
import '../widgets/cloud_browser_body.dart';
import '../widgets/cloud_tv_layout.dart';
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

/// Maps [SortOrder] to the order string expected by the
/// Rust `sort_remote_files` algorithm.
String _sortOrderToString(SortOrder order) {
  switch (order) {
    case SortOrder.nameAsc:
      return 'name_asc';
    case SortOrder.nameDesc:
      return 'name_desc';
    case SortOrder.dateNewest:
      return 'date_newest';
    case SortOrder.dateOldest:
      return 'date_oldest';
    case SortOrder.sizeLargest:
      return 'size_largest';
    case SortOrder.sizeSmallest:
      return 'size_smallest';
  }
}

/// Maps a [classifyFileType] result string to whether the
/// file passes [filter].
bool _classifiedMatchesFilter(String fileType, FileTypeFilter filter) {
  if (filter == FileTypeFilter.all) return true;
  switch (filter) {
    case FileTypeFilter.all:
      return true;
    case FileTypeFilter.video:
      return fileType == 'video';
    case FileTypeFilter.audio:
      return fileType == 'audio';
    case FileTypeFilter.subtitle:
      return fileType == 'subtitle';
    case FileTypeFilter.other:
      return fileType == 'other';
  }
}

/// Serialises a [RemoteFile] to the JSON map expected by
/// the Rust `sort_remote_files` algorithm:
/// `name`, `is_directory`, `modified_at` (epoch ms),
/// `size_bytes`.
Map<String, dynamic> _remoteFileToJson(RemoteFile f) => {
  'name': f.name,
  'is_directory': f.isDirectory,
  'modified_at': f.modifiedAt.millisecondsSinceEpoch,
  'size_bytes': f.sizeBytes,
};

/// Reconstructs a [RemoteFile] from the map returned by
/// the Rust `sort_remote_files` algorithm.
///
/// The Rust function preserves the original JSON fields,
/// so we look up the corresponding [RemoteFile] from the
/// source list by matching `name` + `is_directory`
/// instead of re-parsing dates.
RemoteFile _remoteFileFromJson(
  Map<String, dynamic> m,
  Map<String, RemoteFile> byName,
) {
  final name = m['name'] as String;
  return byName[name] ??
      RemoteFile(
        name: name,
        path: name,
        sizeBytes: (m['size_bytes'] as num?)?.toInt() ?? 0,
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['modified_at'] as num?)?.toInt() ?? 0,
        ),
        isDirectory: m['is_directory'] as bool? ?? false,
      );
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

class _CloudBrowserScreenState extends ConsumerState<CloudBrowserScreen>
    with CloudBrowserActionsMixin {
  StorageBackend? _selectedBackend;
  List<RemoteFile>? _files;
  List<RemoteFile>? _sortedFiles;
  bool _loading = false;
  bool _sorting = false;
  String? _error;
  String _currentPath = '';

  // ── CloudBrowserActionsMixin contract ────────────────────────

  @override
  StorageBackend? get selectedBackend => _selectedBackend;

  @override
  String get currentPath => _currentPath;

  @override
  Future<void> loadFiles(String path) => _loadFiles(path);

  @override
  void exitMultiSelect() => _exitMultiSelect();

  // ── Lifecycle ────────────────────────────────────────────────

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
      _sortedFiles = null;
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
      await _applyFilterAndSort(
        files: files,
        filter: ref.read(fileTypeFilterProvider),
        order: ref.read(sortOrderProvider),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Filter + Sort (via backend) ──────────────────────────────

  Future<void> _applyFilterAndSort({
    required List<RemoteFile> files,
    required FileTypeFilter filter,
    required SortOrder order,
  }) async {
    if (!mounted) return;
    setState(() => _sorting = true);

    try {
      final cache = ref.read(cacheServiceProvider);
      final backend = ref.read(crispyBackendProvider);

      // 1. Filter using sync classifyFileType.
      final filtered =
          files.where((f) {
            if (f.isDirectory) return true;
            final fileType = backend.classifyFileType(f.name);
            return _classifiedMatchesFilter(fileType, filter);
          }).toList();

      // 2. Build maps for Rust sort.
      final fileMaps = filtered.map(_remoteFileToJson).toList();
      final orderStr = _sortOrderToString(order);

      // 3. Sort via CacheService (JSON handled internally).
      final sortedMaps = await cache.sortRemoteFilesParsed(fileMaps, orderStr);

      if (!mounted) return;

      // 4. Deserialize — preserve original RemoteFile instances by name.
      final byName = {for (final f in filtered) f.name: f};
      final sorted =
          sortedMaps.map((m) => _remoteFileFromJson(m, byName)).toList();

      setState(() {
        _sortedFiles = sorted;
        _sorting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sorting = false);
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

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final backends = ref.watch(storageBackendsProvider);
    final isMultiSelect = ref.watch(multiSelectActiveProvider);
    final selectedPaths = ref.watch(selectedPathsProvider);
    final sortOrder = ref.watch(sortOrderProvider);
    ref.watch(fileTypeFilterProvider);

    // Re-apply filter+sort whenever sortOrder or activeFilter changes.
    ref.listen<SortOrder>(sortOrderProvider, (_, next) {
      if (_files != null) {
        _applyFilterAndSort(
          files: _files!,
          filter: ref.read(fileTypeFilterProvider),
          order: next,
        );
      }
    });
    ref.listen<FileTypeFilter>(fileTypeFilterProvider, (_, next) {
      if (_files != null) {
        _applyFilterAndSort(
          files: _files!,
          filter: next,
          order: ref.read(sortOrderProvider),
        );
      }
    });

    final transferState = ref.watch(transferServiceProvider).value;
    final activeTasks = transferState?.tasks ?? [];
    final recentFiles = ref.watch(recentFilesProvider);
    final isS3 = _selectedBackend?.type == StorageType.s3;

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
      body: ScreenTemplate(
        focusRestorationKey: 'cloud-browser',
        compactBody:
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
                      child: CloudBrowserBody(
                        loading: _loading,
                        sorting: _sorting,
                        error: _error,
                        files: _files,
                        sortedFiles: _sortedFiles,
                        isMultiSelect: isMultiSelect,
                        selectedPaths: selectedPaths,
                        activeTasks: activeTasks,
                        recentFiles: recentFiles,
                        isS3Backend: isS3,
                        onRetry: () => _loadFiles(_currentPath),
                        onTapFile: (file) {
                          if (file.isDirectory) {
                            _loadFiles(file.path);
                          } else {
                            ref.read(recentFilesProvider.notifier).add(file);
                          }
                        },
                        onLongPressFile: (file) {
                          if (!isMultiSelect) {
                            _enterMultiSelect(file.path);
                          }
                        },
                        onInfoFile: showMetadata,
                        onCopyLink: isS3 ? (file) => copyLink(file) : null,
                        onToggleSelection: _toggleSelection,
                        onEnterMultiSelect: _enterMultiSelect,
                        syncStatusForFile: syncStatusForFile,
                      ),
                    ),
                  ],
                ),
        largeBody: CloudTvLayout(
          files: _sortedFiles ?? _files,
          onTapFile: (file) {
            if (file.isDirectory) {
              _loadFiles(file.path);
            } else {
              ref.read(recentFilesProvider.notifier).add(file);
            }
          },
        ),
      ),
      bottomNavigationBar:
          isMultiSelect
              ? BulkActionBar(
                selectedCount: selectedPaths.length,
                onDelete:
                    selectedPaths.isEmpty
                        ? null
                        : () => bulkDelete(selectedPaths),
                onDownload:
                    selectedPaths.isEmpty
                        ? null
                        : () => bulkDownload(selectedPaths),
              )
              : null,
      floatingActionButton:
          (!isMultiSelect && _selectedBackend != null)
              ? UploadFab(
                isUploading: ref.watch(uploadActiveProvider),
                onTap: uploadFromDevice,
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
}
