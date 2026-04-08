import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../providers/settings_service_providers.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import 'source_add_dialogs.dart'
    show SourceDialogErrorText, sourceDialogActions, syncSourceAndNotify;
import 'source_form_fields.dart';
import 'source_verify_utils.dart';

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
    final verifyError = await verifySourceConnectivity(
      widget.parentRef,
      PlaylistSourceType.stalkerPortal,
      url,
      macAddress: mac,
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

    // Trigger channel sync.
    await syncSourceAndNotify(
      ref: widget.parentRef,
      messenger: messenger,
      source: source,
      name: name,
      isMounted: widget.isMounted,
    );
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
            SourceDialogErrorText(errorMessage: _error),
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
  showDialog<void>(
    context: context,
    builder:
        (ctx) => _EpgUrlDialog(
          parentRef: ref,
          isMounted: isMounted,
          parentContext: context,
        ),
  );
}

/// Stateful dialog for editing the global EPG URL.
class _EpgUrlDialog extends ConsumerStatefulWidget {
  const _EpgUrlDialog({
    required this.parentRef,
    required this.isMounted,
    required this.parentContext,
  });

  final WidgetRef parentRef;
  final bool Function() isMounted;
  final BuildContext parentContext;

  @override
  ConsumerState<_EpgUrlDialog> createState() => _EpgUrlDialogState();
}

class _EpgUrlDialogState extends ConsumerState<_EpgUrlDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill with persisted value, guarded by mounted check.
    widget.parentRef
        .read(cacheServiceProvider)
        .getSetting(kGlobalEpgUrlKey)
        .then((existing) {
          if (mounted && existing != null && existing.isNotEmpty) {
            _controller.text = existing;
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    final messenger = ScaffoldMessenger.of(widget.parentContext);
    await widget.parentRef
        .read(cacheServiceProvider)
        .setSetting(kGlobalEpgUrlKey, url);
    if (mounted) {
      Navigator.pop(context);
    }
    if (widget.isMounted()) {
      messenger.showSnackBar(const SnackBar(content: Text('EPG URL saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('EPG URL'),
      content: TextField(
        controller: _controller,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
