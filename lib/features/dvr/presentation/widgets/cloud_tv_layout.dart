import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import '../../domain/storage_provider.dart';

/// TV layout for the cloud browser screen.
///
/// Uses [TvMasterDetailLayout] with a file/folder grid on the left
/// and a file preview + metadata panel on the right.
class CloudTvLayout extends StatefulWidget {
  /// Creates a TV layout for the cloud browser.
  const CloudTvLayout({
    required this.files,
    required this.onTapFile,
    super.key,
  });

  /// The list of files to display in the master panel.
  final List<RemoteFile>? files;

  /// Callback when a file is tapped in the grid.
  final ValueChanged<RemoteFile> onTapFile;

  @override
  State<CloudTvLayout> createState() => _CloudTvLayoutState();
}

class _CloudTvLayoutState extends State<CloudTvLayout> {
  RemoteFile? _selectedFile;

  @override
  Widget build(BuildContext context) {
    return TvMasterDetailLayout(
      showDetail: _selectedFile != null,
      onDetailDismissed: () => setState(() => _selectedFile = null),
      masterPanel: _FileMasterPanel(
        files: widget.files,
        selectedFile: _selectedFile,
        onFileFocused: (_) {},
        onFileSelected: (file) {
          if (file.isDirectory) {
            widget.onTapFile(file);
          } else {
            setState(() => _selectedFile = file);
          }
        },
      ),
      detailPanel: _FileDetailPanel(file: _selectedFile),
    );
  }
}

/// Left panel: scrollable grid of files and folders.
class _FileMasterPanel extends StatelessWidget {
  const _FileMasterPanel({
    required this.files,
    required this.selectedFile,
    required this.onFileFocused,
    required this.onFileSelected,
  });

  final List<RemoteFile>? files;
  final RemoteFile? selectedFile;
  final ValueChanged<RemoteFile> onFileFocused;
  final ValueChanged<RemoteFile> onFileSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (files == null || files!.isEmpty) {
      return const Center(child: Text('No files'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(CrispySpacing.md),
      itemCount: files!.length,
      itemBuilder: (context, index) {
        final file = files![index];
        final isSelected = file.name == selectedFile?.name;

        return Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) onFileFocused(file);
          },
          child: ListTile(
            leading: Icon(
              file.isDirectory ? Icons.folder : Icons.insert_drive_file,
              color: file.isDirectory ? cs.primary : cs.onSurfaceVariant,
            ),
            title: Text(file.name),
            subtitle:
                file.isDirectory ? null : Text(_formatSize(file.sizeBytes)),
            selected: isSelected,
            selectedTileColor: cs.primaryContainer.withValues(alpha: 0.3),
            onTap: () => onFileSelected(file),
          ),
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Right panel: file preview and metadata.
class _FileDetailPanel extends StatelessWidget {
  const _FileDetailPanel({required this.file});

  final RemoteFile? file;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (file == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_outlined,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: CrispySpacing.md),
            Text(
              'Select a file to preview',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File icon
          Center(
            child: Icon(
              file!.isDirectory ? Icons.folder : Icons.insert_drive_file,
              size: 96,
              color: file!.isDirectory ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: CrispySpacing.lg),

          // File name
          Text(
            file!.name,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: CrispySpacing.md),

          // Metadata
          _MetadataRow(
            label: 'Type',
            value: file!.isDirectory ? 'Folder' : 'File',
          ),
          if (!file!.isDirectory)
            _MetadataRow(label: 'Size', value: _formatSize(file!.sizeBytes)),
          _MetadataRow(label: 'Modified', value: _formatDate(file!.modifiedAt)),
          _MetadataRow(label: 'Path', value: file!.path),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

/// A label-value metadata row.
class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: tt.bodyMedium)),
        ],
      ),
    );
  }
}
