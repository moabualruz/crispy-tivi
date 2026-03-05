import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/network/http_service.dart';
import '../../../iptv/application/playlist_sync_service.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../../../iptv/data/parsers/xtream_client.dart';
import 'source_form_fields.dart';

/// Shows a dialog to add an M3U playlist source.
void showAddM3uDialog({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
}) {
  showDialog<void>(
    context: context,
    builder:
        (ctx) => _M3uAddDialog(
          parentRef: ref,
          isMounted: isMounted,
          parentContext: context,
        ),
  );
}

/// Stateful dialog for adding an M3U source with server
/// verification before saving.
class _M3uAddDialog extends ConsumerStatefulWidget {
  const _M3uAddDialog({
    required this.parentRef,
    required this.isMounted,
    required this.parentContext,
  });

  final WidgetRef parentRef;
  final bool Function() isMounted;
  final BuildContext parentContext;

  @override
  ConsumerState<_M3uAddDialog> createState() => _M3uAddDialogState();
}

class _M3uAddDialogState extends ConsumerState<_M3uAddDialog> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _isVerifying = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'URL is required.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    // Verify URL is reachable before saving.
    final verifyError = await HttpService.verifyM3uUrl(
      http: widget.parentRef.read(httpServiceProvider),
      url: url,
    );
    if (!mounted) return;
    if (verifyError != null) {
      setState(() {
        _isVerifying = false;
        _error = verifyError;
      });
      return;
    }
    setState(() => _isVerifying = false);

    final name =
        _nameCtrl.text.trim().isEmpty ? 'M3U Playlist' : _nameCtrl.text.trim();
    if (!widget.parentContext.mounted) return;
    final messenger = ScaffoldMessenger.of(widget.parentContext);

    final source = PlaylistSource(
      id: PlaylistSource.generateId(),
      name: name,
      url: url,
      type: PlaylistSourceType.m3u,
    );
    widget.parentRef.read(settingsNotifierProvider.notifier).addSource(source);
    if (mounted) Navigator.pop(context);

    messenger.showSnackBar(
      const SnackBar(content: Text('Source added \u2014 syncing\u2026')),
    );

    // Trigger channel sync.
    try {
      final result = await widget.parentRef
          .read(playlistSyncServiceProvider)
          .syncSource(source);
      if (!widget.isMounted()) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Loaded ${result.totalChannels} channels '
            'from "$name"',
          ),
        ),
      );
    } catch (e) {
      if (!widget.isMounted()) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Sync failed for "$name": $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add M3U Playlist'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            M3uFormFields(nameCtrl: _nameCtrl, urlCtrl: _urlCtrl),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isVerifying ? null : _submit,
          child:
              _isVerifying
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Add'),
        ),
      ],
    );
  }
}

/// Shows a dialog to add an Xtream Codes source.
void showAddXtreamDialog({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
}) {
  showDialog<void>(
    context: context,
    builder:
        (ctx) => _XtreamAddDialog(
          parentRef: ref,
          isMounted: isMounted,
          parentContext: context,
        ),
  );
}

/// Stateful dialog for adding an Xtream source with server
/// verification before saving.
class _XtreamAddDialog extends ConsumerStatefulWidget {
  const _XtreamAddDialog({
    required this.parentRef,
    required this.isMounted,
    required this.parentContext,
  });

  final WidgetRef parentRef;
  final bool Function() isMounted;
  final BuildContext parentContext;

  @override
  ConsumerState<_XtreamAddDialog> createState() => _XtreamAddDialogState();
}

class _XtreamAddDialogState extends ConsumerState<_XtreamAddDialog> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isVerifying = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _urlCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (url.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    // Verify credentials before saving.
    final verifyError = await XtreamClient.verifyCredentials(
      http: widget.parentRef.read(httpServiceProvider),
      serverUrl: url,
      username: user,
      password: pass,
    );
    if (!mounted) return;
    if (verifyError != null) {
      setState(() {
        _isVerifying = false;
        _error = verifyError;
      });
      return;
    }
    setState(() => _isVerifying = false);

    final name =
        _nameCtrl.text.trim().isEmpty
            ? 'Xtream Provider'
            : _nameCtrl.text.trim();
    if (!widget.parentContext.mounted) return;
    final messenger = ScaffoldMessenger.of(widget.parentContext);

    final source = PlaylistSource(
      id: PlaylistSource.generateId(),
      name: name,
      url: url,
      type: PlaylistSourceType.xtream,
      username: user,
      password: pass,
      epgUrl: PlaylistSource.buildXtreamEpgUrl(url, user, pass),
    );
    widget.parentRef.read(settingsNotifierProvider.notifier).addSource(source);
    if (mounted) Navigator.pop(context);

    messenger.showSnackBar(
      const SnackBar(content: Text('Source added \u2014 syncing\u2026')),
    );

    // Trigger channel sync.
    try {
      final result = await widget.parentRef
          .read(playlistSyncServiceProvider)
          .syncSource(source);
      if (!widget.isMounted()) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Loaded ${result.totalChannels} channels from "$name"'),
        ),
      );
    } catch (e) {
      if (!widget.isMounted()) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Sync failed for "$name": $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Xtream Codes'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            XtreamFormFields(
              nameCtrl: _nameCtrl,
              urlCtrl: _urlCtrl,
              userCtrl: _userCtrl,
              passCtrl: _passCtrl,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isVerifying ? null : _submit,
          child:
              _isVerifying
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Add'),
        ),
      ],
    );
  }
}
