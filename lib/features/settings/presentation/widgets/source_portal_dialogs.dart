import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/data/cache_service.dart';
import '../../../iptv/application/playlist_sync_service.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import 'source_add_dialogs.dart' show sourceDialogActions;
import 'source_form_fields.dart';

/// Shows a dialog to add a Stalker Portal source.
void showAddStalkerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
}) {
  showDialog<void>(
    context: context,
    builder:
        (ctx) => _StalkerAddDialog(
          parentRef: ref,
          isMounted: isMounted,
          parentContext: context,
        ),
  );
}

/// Stateful dialog for adding a Stalker Portal source
/// with server verification before saving.
class _StalkerAddDialog extends ConsumerStatefulWidget {
  const _StalkerAddDialog({
    required this.parentRef,
    required this.isMounted,
    required this.parentContext,
  });

  final WidgetRef parentRef;
  final bool Function() isMounted;
  final BuildContext parentContext;

  @override
  ConsumerState<_StalkerAddDialog> createState() => _StalkerAddDialogState();
}

class _StalkerAddDialogState extends ConsumerState<_StalkerAddDialog> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _macCtrl = TextEditingController();
  bool _isVerifying = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _macCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _urlCtrl.text.trim();
    final mac = _macCtrl.text.trim().toUpperCase();
    if (url.isEmpty || mac.isEmpty) {
      setState(() => _error = 'URL and MAC address are required.');
      return;
    }

    if (!kMacAddressRegExp.hasMatch(mac)) {
      setState(
        () =>
            _error =
                'Invalid MAC address format. '
                'Use XX:XX:XX:XX:XX:XX.',
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    // Verify portal via Rust backend.
    try {
      final backend = widget.parentRef.read(crispyBackendProvider);
      final ok = await backend.verifyStalkerPortal(
        baseUrl: url,
        macAddress: mac,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _isVerifying = false;
          _error = 'Portal authentication failed. Check URL and MAC.';
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error = 'Connection error: $e';
      });
      return;
    }
    setState(() => _isVerifying = false);

    final name =
        _nameCtrl.text.trim().isEmpty
            ? 'Stalker Portal'
            : _nameCtrl.text.trim();
    if (!widget.parentContext.mounted) return;
    final messenger = ScaffoldMessenger.of(widget.parentContext);

    final source = PlaylistSource(
      id: PlaylistSource.generateId(),
      name: name,
      url: url,
      type: PlaylistSourceType.stalkerPortal,
      macAddress: mac,
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
      title: const Text('Add Stalker Portal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StalkerFormFields(
              nameCtrl: _nameCtrl,
              urlCtrl: _urlCtrl,
              macCtrl: _macCtrl,
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
      actions: sourceDialogActions(
        isVerifying: _isVerifying,
        onCancel: () => Navigator.pop(context),
        onSubmit: _submit,
      ),
    );
  }
}

/// Shows a dialog to set the global EPG URL.
void showEpgUrlDialog({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
}) {
  final controller = TextEditingController();

  // Pre-fill with existing value.
  ref.read(cacheServiceProvider).getSetting(kGlobalEpgUrlKey).then((existing) {
    if (existing != null && existing.isNotEmpty) {
      controller.text = existing;
    }
  });

  showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('EPG URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'XMLTV URL',
              hintText: 'https://example.com/epg.xml',
              prefixIcon: Icon(Icons.calendar_today),
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final url = controller.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                await ref
                    .read(cacheServiceProvider)
                    .setSetting(kGlobalEpgUrlKey, url);
                if (context.mounted) {
                  Navigator.pop(ctx);
                }
                if (isMounted()) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('EPG URL saved')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
  ).then((_) => controller.dispose());
}
