import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/domain/entities/playlist_source.dart';
import '../../../../../core/theme/crispy_animation.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../shared/presentation/screens/media_server_login_screen.dart'
    show kLoginFormMaxWidth;
import '../../utils/error_sanitizer.dart';
import '../../../../iptv/application/playlist_sync_service.dart';

/// Modal dialog that shows sync progress after a media server login.
///
/// Displays a spinner while syncing, a success summary on completion,
/// or an error message with a retry button on failure.
class SyncProgressDialog extends ConsumerStatefulWidget {
  const SyncProgressDialog({super.key, required this.source});

  /// The source to sync.
  final PlaylistSource source;

  /// Shows the dialog and returns `true` if sync succeeded.
  static Future<bool> show(BuildContext context, PlaylistSource source) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SyncProgressDialog(source: source),
    ).then((v) => v ?? false);
  }

  @override
  ConsumerState<SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends ConsumerState<SyncProgressDialog> {
  bool _isSyncing = true;
  String? _error;
  SyncReport? _report;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
      _error = null;
      _report = null;
    });

    try {
      final report = await ref
          .read(playlistSyncServiceProvider)
          .syncSource(widget.source);

      if (!mounted) return;

      setState(() {
        _isSyncing = false;
        _report = report;
      });

      // Auto-dismiss after a short delay on success.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e, stack) {
      debugPrint('SyncProgressDialog error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _error = _formatError(e);
      });
    }
  }

  String _formatError(Object e) => sanitizeError(e);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CrispyRadius.md),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: kLoginFormMaxWidth),
        padding: const EdgeInsets.all(CrispySpacing.xl),
        child: AnimatedSize(
          duration: CrispyAnimation.normal,
          curve: CrispyAnimation.enterCurve,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSyncing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: CrispySpacing.lg),
                Text('Syncing libraries…', style: tt.titleMedium),
                const SizedBox(height: CrispySpacing.sm),
                Text(
                  widget.source.name,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ] else if (_error != null) ...[
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: CrispySpacing.lg),
                Text('Sync Failed', style: tt.titleMedium),
                const SizedBox(height: CrispySpacing.sm),
                Text(
                  _error!,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: CrispySpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: CrispySpacing.sm),
                    FilledButton(
                      onPressed: _startSync,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ] else if (_report != null) ...[
                Icon(Icons.check_circle_outline, size: 48, color: cs.primary),
                const SizedBox(height: CrispySpacing.lg),
                Text('Sync Complete', style: tt.titleMedium),
                const SizedBox(height: CrispySpacing.sm),
                Text(
                  '${_report!.channelsCount} channels, '
                  '${_report!.vodCount} movies',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
