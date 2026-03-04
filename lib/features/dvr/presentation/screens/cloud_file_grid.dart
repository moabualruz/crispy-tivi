import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../domain/entities/storage_backend.dart';
import '../../domain/storage_provider.dart';
import 'cloud_browser_providers.dart';

/// Bytes in one megabyte (binary).
const int kBytesPerMb = 1024 * 1024;

/// Height of the bulk-action bar at the bottom of the screen.
const double kBulkBarHeight = 64.0;

// ── FE-CB-01: File-type helpers ────────────────────────────────────

/// Returns the appropriate [IconData] for a file based on its extension.
IconData fileTypeIcon(String name) {
  if (name.isEmpty) return Icons.insert_drive_file;
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'mp4':
    case 'mkv':
    case 'avi':
    case 'mov':
    case 'ts':
    case 'mpg':
    case 'mpeg':
    case 'm2ts':
    case 'wmv':
    case 'flv':
    case 'webm':
    case 'm4v':
      return Icons.video_file;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
    case 'bmp':
      return Icons.image;
    case 'mp3':
    case 'aac':
    case 'flac':
    case 'ogg':
    case 'wav':
    case 'opus':
    case 'm4a':
      return Icons.audio_file;
    case 'srt':
    case 'ass':
    case 'ssa':
    case 'vtt':
    case 'sub':
      return Icons.subtitles;
    default:
      return Icons.insert_drive_file;
  }
}

/// Returns true if [name] has a video file extension.
bool isVideoFile(String name) {
  if (!name.contains('.')) return false;
  final ext = name.split('.').last.toLowerCase();
  return const {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'ts',
    'mpg',
    'mpeg',
    'm2ts',
    'wmv',
    'flv',
    'webm',
    'm4v',
  }.contains(ext);
}

/// Returns true if [name] has an image file extension.
bool isImageFile(String name) {
  if (!name.contains('.')) return false;
  final ext = name.split('.').last.toLowerCase();
  return const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext);
}

// ── FE-CB-06: Sync status badge ────────────────────────────────────

/// Small overlay icon showing upload/sync/error state.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    switch (status) {
      case SyncStatus.none:
        return const SizedBox.shrink();
      case SyncStatus.uploading:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: cs.primary),
        );
      case SyncStatus.synced:
        return Icon(Icons.check_circle_outline, size: 14, color: cs.primary);
      case SyncStatus.error:
        return Icon(Icons.error_outline, size: 14, color: cs.error);
    }
  }
}

// ── FE-CB-01: Leading thumbnail widget ────────────────────────────

/// Leading widget for [RemoteFileCard] — shows thumbnail or file-type icon.
///
/// A [SyncStatusBadge] is overlaid on the bottom-right corner when
/// [syncStatus] is not [SyncStatus.none].
class FileThumbnail extends StatelessWidget {
  const FileThumbnail({
    super.key,
    required this.file,
    required this.syncStatus,
    required this.iconColor,
  });

  final RemoteFile file;
  final SyncStatus syncStatus;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget icon;

    if (file.isDirectory) {
      icon = Icon(Icons.folder, color: iconColor);
    } else if (isImageFile(file.name)) {
      icon = ClipRRect(
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        child: Image.network(
          file.path,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) =>
                  Icon(Icons.broken_image, color: iconColor),
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.primary,
                ),
              ),
            );
          },
        ),
      );
    } else if (isVideoFile(file.name)) {
      icon = Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.video_file, color: iconColor),
          Positioned(
            bottom: 0,
            right: 0,
            child: Icon(
              Icons.movie_outlined,
              size: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      );
    } else {
      icon = Icon(fileTypeIcon(file.name), color: iconColor);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        if (syncStatus != SyncStatus.none)
          Positioned(
            bottom: -2,
            right: -4,
            child: SyncStatusBadge(status: syncStatus),
          ),
      ],
    );
  }
}

// ── Remote file card ───────────────────────────────────────────────

/// Card for a single remote file or folder.
class RemoteFileCard extends StatelessWidget {
  const RemoteFileCard({
    super.key,
    required this.file,
    required this.isMultiSelect,
    required this.isSelected,
    required this.syncStatus,
    required this.isS3Backend,
    required this.onTap,
    required this.onLongPress,
    required this.onInfo,
    this.onCopyLink,
  });

  final RemoteFile file;
  final bool isMultiSelect;
  final bool isSelected;
  final SyncStatus syncStatus;
  final bool isS3Backend;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onInfo;
  final VoidCallback? onCopyLink;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sizeMB = file.sizeBytes / kBytesPerMb;

    return FocusWrapper(
      onSelect: onTap,
      borderRadius: CrispyRadius.none,
      scaleFactor: 1.02,
      semanticLabel: file.name,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: CrispyAnimation.fast,
          margin: const EdgeInsets.only(bottom: CrispySpacing.xs),
          decoration: BoxDecoration(
            color: isSelected ? cs.primaryContainer : null,
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
          ),
          child: Card(
            margin: EdgeInsets.zero,
            color: isSelected ? cs.primaryContainer : null,
            child: ListTile(
              leading:
                  isMultiSelect
                      ? AnimatedSwitcher(
                        duration: CrispyAnimation.fast,
                        child:
                            isSelected
                                ? Icon(
                                  Icons.check_circle,
                                  key: const ValueKey(true),
                                  color: cs.primary,
                                )
                                : Icon(
                                  Icons.radio_button_unchecked,
                                  key: const ValueKey(false),
                                  color: cs.onSurfaceVariant,
                                ),
                      )
                      : FileThumbnail(
                        file: file,
                        syncStatus: syncStatus,
                        iconColor: cs.primary,
                      ),
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? cs.onPrimaryContainer : null,
                ),
              ),
              subtitle:
                  file.isDirectory
                      ? null
                      : Text(
                        '${sizeMB.toStringAsFixed(1)}'
                        ' MB · '
                        '${formatDMY(file.modifiedAt)}',
                        style: TextStyle(
                          color:
                              isSelected
                                  ? cs.onPrimaryContainer.withValues(alpha: 0.7)
                                  : null,
                        ),
                      ),
              trailing:
                  isMultiSelect
                      ? null
                      : file.isDirectory
                      ? const Icon(Icons.chevron_right)
                      : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isS3Backend && onCopyLink != null)
                            Tooltip(
                              message: 'Copy link',
                              child: IconButton(
                                icon: Icon(
                                  Icons.link,
                                  color: cs.onSurfaceVariant,
                                ),
                                onPressed: onCopyLink,
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          Tooltip(
                            message: 'File info',
                            child: IconButton(
                              icon: Icon(
                                Icons.info_outline,
                                color: cs.onSurfaceVariant,
                              ),
                              onPressed: onInfo,
                            ),
                          ),
                        ],
                      ),
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}

// ── FE-CB-09: Recent files row ────────────────────────────────────

/// Horizontally scrollable row of recently opened files.
class RecentFilesRow extends StatelessWidget {
  const RecentFilesRow({
    super.key,
    required this.recentFiles,
    required this.onTap,
  });

  final List<RemoteFile> recentFiles;
  final ValueChanged<RemoteFile> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: CrispySpacing.md,
            top: CrispySpacing.sm,
            bottom: CrispySpacing.xs,
          ),
          child: Text(
            'Recent',
            style: textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
            itemCount: recentFiles.length,
            separatorBuilder:
                (context, i) => const SizedBox(width: CrispySpacing.sm),
            itemBuilder: (_, index) {
              final file = recentFiles[index];
              return FocusWrapper(
                onSelect: () => onTap(file),
                borderRadius: CrispyRadius.tv,
                semanticLabel: 'Recent: ${file.name}',
                child: InkWell(
                  onTap: () => onTap(file),
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  child: Container(
                    width: 160,
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.sm,
                      vertical: CrispySpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(CrispyRadius.tv),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          file.isDirectory ? Icons.folder : Icons.video_file,
                          color: cs.primary,
                          size: 20,
                        ),
                        const SizedBox(width: CrispySpacing.xs),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface,
                                ),
                              ),
                              Text(
                                formatDMY(file.modifiedAt),
                                style: textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Divider(
          height: CrispySpacing.md,
          indent: CrispySpacing.md,
          endIndent: CrispySpacing.md,
          color: cs.outlineVariant,
        ),
      ],
    );
  }
}

// ── Bulk action bar ────────────────────────────────────────────────

/// Floating bulk-action bar shown at the bottom in multi-select mode.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.selectedCount,
    this.onDelete,
    this.onDownload,
  });

  final int selectedCount;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: CrispyAnimation.fast,
      height: kBulkBarHeight,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.sm,
        ),
        child: Row(
          children: [
            Text(
              '$selectedCount item${selectedCount == 1 ? '' : 's'} selected',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            Tooltip(
              message: 'Download selected',
              child: IconButton.filled(
                icon: const Icon(Icons.download),
                onPressed: onDownload,
                style: IconButton.styleFrom(
                  backgroundColor:
                      selectedCount > 0
                          ? cs.secondaryContainer
                          : cs.surfaceContainerHighest,
                  foregroundColor:
                      selectedCount > 0
                          ? cs.onSecondaryContainer
                          : cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: CrispySpacing.sm),
            Tooltip(
              message: 'Delete selected',
              child: IconButton.filled(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
                style: IconButton.styleFrom(
                  backgroundColor:
                      selectedCount > 0
                          ? cs.errorContainer
                          : cs.surfaceContainerHighest,
                  foregroundColor:
                      selectedCount > 0
                          ? cs.onErrorContainer
                          : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upload FAB ────────────────────────────────────────────────────

/// Floating action button that triggers an upload from the device.
class UploadFab extends StatelessWidget {
  const UploadFab({super.key, required this.isUploading, required this.onTap});

  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isUploading ? 'Upload in progress…' : 'Upload from device',
      child: FloatingActionButton.extended(
        onPressed: isUploading ? null : onTap,
        icon:
            isUploading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.upload),
        label: Text(isUploading ? 'Uploading…' : 'Upload'),
      ),
    );
  }
}

// ── Path bar ──────────────────────────────────────────────────────

/// Breadcrumb path bar with back navigation.
class CloudPathBar extends StatelessWidget {
  const CloudPathBar({
    super.key,
    required this.backend,
    required this.currentPath,
    this.onGoUp,
  });

  final StorageBackend backend;
  final String currentPath;
  final VoidCallback? onGoUp;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.xs,
      ),
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.cloud, size: 16, color: cs.primary),
          const SizedBox(width: CrispySpacing.sm),
          Text(
            backend.name,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (currentPath.isNotEmpty) ...[
            const SizedBox(width: CrispySpacing.xs),
            Expanded(
              child: Text(
                ' / $currentPath',
                style: TextStyle(color: cs.outline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          if (onGoUp != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: 'Go up',
              onPressed: onGoUp,
            ),
        ],
      ),
    );
  }
}

// ── Empty backends placeholder ─────────────────────────────────────

/// Placeholder shown when no backends are configured.
class EmptyBackendsPlaceholder extends StatelessWidget {
  const EmptyBackendsPlaceholder({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: CrispySpacing.sm),
          const Text('No storage backends configured'),
          const SizedBox(height: CrispySpacing.xs),
          Text(
            'Add one in Settings → Cloud Storage',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: CrispySpacing.md),
          FilledButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Open Cloud Storage Settings'),
          ),
        ],
      ),
    );
  }
}

// ── FE-CB-02: Filter chip bar ─────────────────────────────────────

/// Horizontal row of file-type filter chips.
class CloudFilterChipBar extends ConsumerWidget {
  const CloudFilterChipBar({super.key, required this.onFilterChanged});

  final ValueChanged<FileTypeFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(fileTypeFilterProvider);
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      child: Row(
        children:
            FileTypeFilter.values.map((filter) {
              final isSelected = filter == active;
              return Padding(
                padding: const EdgeInsets.only(right: CrispySpacing.xs),
                child: FilterChip(
                  label: Text(filter.label),
                  selected: isSelected,
                  onSelected: (_) => onFilterChanged(filter),
                  selectedColor: cs.secondaryContainer,
                  checkmarkColor: cs.onSecondaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected ? cs.onSecondaryContainer : null,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  showCheckmark: true,
                  side: BorderSide(
                    color: isSelected ? cs.secondaryContainer : cs.outline,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

// ── Upload dialog ─────────────────────────────────────────────────

/// Opens the system file picker to select files for upload.
///
/// FE-CB-08: Actual file_picker integration replacing the stub.
Future<List<String>?> pickFilesToUpload() async {
  final result = await FilePicker.platform.pickFiles(allowMultiple: true);
  if (result != null) {
    return result.paths.whereType<String>().toList();
  }
  return null;
}
