import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../domain/storage_provider.dart';

// ── Sheet size constants ──────────────────────────────────────────

/// Default fractional height of the metadata sheet.
const double _kSheetInitialSize = 0.55;

/// Minimum fractional height (collapsed).
const double _kSheetMinSize = 0.35;

/// Maximum fractional height (expanded).
const double _kSheetMaxSize = 0.85;

/// Width of the drag handle pill.
const double _kDragHandleWidth = 40.0;

/// Height of the drag handle pill.
const double _kDragHandleHeight = 4.0;

/// Size of the file type icon in the header.
const double _kFileIconSize = 48.0;

/// Bytes in one megabyte (binary).
const int _kBytesPerMb = 1024 * 1024;

/// Bytes in one gigabyte (binary).
const int _kBytesPerGb = 1024 * 1024 * 1024;

// ── File type helpers ─────────────────────────────────────────────

/// Returns an icon appropriate for a given file name or directory.
IconData _iconForFile(RemoteFile file) {
  if (file.isDirectory) return Icons.folder;
  final ext = file.name.split('.').last.toLowerCase();
  return switch (ext) {
    'mp4' ||
    'mkv' ||
    'avi' ||
    'mov' ||
    'ts' ||
    'mpg' ||
    'wmv' => Icons.video_file,
    'mp3' || 'aac' || 'flac' || 'wav' || 'ogg' => Icons.audio_file,
    'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' => Icons.image,
    'pdf' => Icons.picture_as_pdf,
    'zip' || 'tar' || 'gz' || 'rar' || '7z' => Icons.folder_zip,
    _ => Icons.insert_drive_file,
  };
}

/// Returns a human-readable file type label.
String _typeLabel(RemoteFile file) {
  if (file.isDirectory) return 'Folder';
  final ext = file.name.split('.').last.toUpperCase();
  return '$ext File';
}

/// Formats [bytes] as a human-readable size string.
String _formatSize(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes >= _kBytesPerGb) {
    return '${(bytes / _kBytesPerGb).toStringAsFixed(2)} GB';
  }
  if (bytes >= _kBytesPerMb) {
    return '${(bytes / _kBytesPerMb).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

/// A bottom sheet that displays metadata for a [RemoteFile].
///
/// Shows: name, size, type, last modified, full path, and
/// quick actions (Play, Download, Delete, Copy Link).
class FileMetadataSheet extends StatelessWidget {
  const FileMetadataSheet({
    super.key,
    required this.file,
    required this.backendName,
    this.onPlay,
    this.onDownload,
    this.onDelete,
    this.onCopyLink,
  });

  /// The file to display metadata for.
  final RemoteFile file;

  /// Display name of the current storage backend.
  final String backendName;

  /// Called when the user taps Play. Null hides the action.
  final VoidCallback? onPlay;

  /// Called when the user taps Download. Null hides the action.
  final VoidCallback? onDownload;

  /// Called when the user taps Delete. Null hides the action.
  final VoidCallback? onDelete;

  /// Called when the user taps Copy Link. Null hides the action.
  final VoidCallback? onCopyLink;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _kSheetInitialSize,
      minChildSize: _kSheetMinSize,
      maxChildSize: _kSheetMaxSize,
      expand: false,
      builder: (context, scrollController) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: CrispyRadius.top(CrispyRadius.tv),
          ),
          child: Column(
            children: [
              // Drag handle.
              Container(
                margin: const EdgeInsets.only(top: CrispySpacing.sm),
                width: _kDragHandleWidth,
                height: _kDragHandleHeight,
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                ),
              ),

              // Header: icon + name.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CrispySpacing.md,
                  CrispySpacing.md,
                  CrispySpacing.md,
                  CrispySpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: _kFileIconSize,
                      height: _kFileIconSize,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(CrispyRadius.tv),
                      ),
                      child: Icon(
                        _iconForFile(file),
                        size: 28,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: CrispySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: CrispySpacing.xxs),
                          Text(
                            _typeLabel(file),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Close button.
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Scrollable content.
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.md,
                    vertical: CrispySpacing.sm,
                  ),
                  children: [
                    // Metadata rows.
                    _MetadataRow(
                      icon: Icons.straighten,
                      label: 'Size',
                      value:
                          file.isDirectory ? '—' : _formatSize(file.sizeBytes),
                    ),
                    _MetadataRow(
                      icon: Icons.schedule,
                      label: 'Modified',
                      value: formatDMYHHmm(file.modifiedAt),
                    ),
                    _MetadataRow(
                      icon: Icons.cloud,
                      label: 'Backend',
                      value: backendName,
                    ),
                    _MetadataRow(
                      icon: Icons.folder_open,
                      label: 'Location',
                      value: file.path,
                      selectable: true,
                    ),

                    const SizedBox(height: CrispySpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: CrispySpacing.sm),

                    // Quick actions.
                    Text(
                      'Actions',
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: CrispySpacing.sm),
                    _QuickActions(
                      file: file,
                      onPlay: onPlay,
                      onDownload: onDownload,
                      onDelete: onDelete,
                      onCopyLink: onCopyLink,
                    ),
                    const SizedBox(height: CrispySpacing.lg),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A single labelled metadata row.
class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// When true, wraps value in [SelectableText].
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: CrispySpacing.sm),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child:
                selectable
                    ? SelectableText(value, style: tt.bodyMedium)
                    : Text(value, style: tt.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Horizontal row of quick action chips/buttons.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.file,
    this.onPlay,
    this.onDownload,
    this.onDelete,
    this.onCopyLink,
  });

  final RemoteFile file;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onCopyLink;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMedia = !file.isDirectory;

    return Wrap(
      spacing: CrispySpacing.sm,
      runSpacing: CrispySpacing.sm,
      children: [
        if (isMedia && onPlay != null)
          _ActionChip(
            icon: Icons.play_circle_outline,
            label: 'Play',
            color: cs.primary,
            onTap: onPlay!,
          ),
        if (!file.isDirectory && onDownload != null)
          _ActionChip(
            icon: Icons.download_outlined,
            label: 'Download',
            color: cs.secondary,
            onTap: onDownload!,
          ),
        if (onCopyLink != null)
          _ActionChip(
            icon: Icons.link,
            label: 'Copy Link',
            color: cs.tertiary,
            onTap: onCopyLink!,
          ),
        if (onDelete != null)
          _ActionChip(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: cs.error,
            onTap: onDelete!,
          ),
      ],
    );
  }
}

/// A single tappable action chip with icon + label.
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: 1.0,
      duration: CrispyAnimation.fast,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: CrispySpacing.xs),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the [FileMetadataSheet] as a modal bottom sheet.
///
/// [onPlay], [onDownload], [onDelete], and [onCopyLink] are
/// forwarded to the sheet's quick-action buttons and are
/// automatically hidden when null.
Future<void> showFileMetadataSheet({
  required BuildContext context,
  required RemoteFile file,
  required String backendName,
  VoidCallback? onPlay,
  VoidCallback? onDownload,
  VoidCallback? onDelete,
  VoidCallback? onCopyLink,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => FileMetadataSheet(
          file: file,
          backendName: backendName,
          onPlay: onPlay,
          onDownload: onDownload,
          onDelete: onDelete,
          onCopyLink: onCopyLink,
        ),
  );
}
