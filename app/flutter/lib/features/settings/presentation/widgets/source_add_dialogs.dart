import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/async_filled_button.dart';
import '../../../iptv/presentation/providers/playlist_sync_service.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import 'source_form_fields.dart';
import 'source_verify_utils.dart';

/// Triggers a channel sync for [source] and shows snackbar feedback.
///
/// Shows an initial "syncing…" snackbar, then either a success message with
/// the channel count or an error message if the sync fails.
///
/// [isMounted] guards against showing snackbars after the parent widget
/// has been disposed (e.g. the settings screen was popped).
Future<void> syncSourceAndNotify({
  required WidgetRef ref,
  required ScaffoldMessengerState messenger,
  required PlaylistSource source,
  required String name,
  required bool Function() isMounted,
}) async {
  messenger.showSnackBar(
    const SnackBar(content: Text('Source added \u2014 syncing\u2026')),
  );
  try {
    final result = await ref
        .read(playlistSyncServiceProvider)
        .syncSource(source);
    if (!isMounted()) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Loaded ${result.totalChannels} channels from "$name"'),
      ),
    );
  } catch (e) {
    if (!isMounted()) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Sync failed for "$name": $e')),
    );
  }
}

Future<void> _addSourceAndSync({
  required WidgetRef ref,
  required ScaffoldMessengerState messenger,
  required PlaylistSource source,
  required String name,
  required bool Function() isMounted,
}) async {
  await ref.read(settingsNotifierProvider.notifier).addSource(source);

  await syncSourceAndNotify(
    ref: ref,
    messenger: messenger,
    source: source,
    name: name,
    isMounted: isMounted,
  );
}

/// Returns the standard [Cancel | Add] action list for source-add dialogs.
///
/// Shared by [_M3uAddDialog], [_XtreamAddDialog], and [_StalkerAddDialog].
/// Use this helper instead of duplicating the pattern inline.
///
/// - When [isVerifying] is `true`, Cancel is disabled and the submit button
///   shows a loading spinner (via [AsyncFilledButton]).
/// - [submitLabel] defaults to `'Add'`; override for different button text.
List<Widget> sourceDialogActions({
  required bool isVerifying,
  required VoidCallback onCancel,
  required VoidCallback onSubmit,
  String submitLabel = 'Add',
}) => [
  TextButton(
    onPressed: isVerifying ? null : onCancel,
    child: const Text('Cancel'),
  ),
  AsyncFilledButton(
    isLoading: isVerifying,
    label: submitLabel,
    onPressed: onSubmit,
  ),
];

/// Inline error message widget for source-add dialogs.
///
/// Renders [errorMessage] in [ColorScheme.error] colour when non-null,
/// preceded by a small vertical gap. Returns an empty widget when null.
///
/// Use inside a [Column] where `_error` state is tracked:
/// ```dart
/// SourceDialogErrorText(errorMessage: _error),
/// ```
class SourceDialogErrorText extends StatelessWidget {
  const SourceDialogErrorText({super.key, required this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CrispySpacing.sm),
        Text(
          errorMessage!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

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
    final messenger = ScaffoldMessenger.of(widget.parentContext);

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    // Verify URL is reachable before saving.
    final verifyError = await verifySourceConnectivity(
      widget.parentRef,
      PlaylistSourceType.m3u,
      url,
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
    final source = PlaylistSource(
      id: PlaylistSource.generateId(),
      name: name,
      url: url,
      type: PlaylistSourceType.m3u,
    );
    if (context.mounted) Navigator.pop(context);
    await _addSourceAndSync(
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
      title: const Text('Add M3U Playlist'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            M3uFormFields(nameCtrl: _nameCtrl, urlCtrl: _urlCtrl),
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
    final messenger = ScaffoldMessenger.of(widget.parentContext);

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    // Verify credentials via Rust backend.
    final verifyError = await verifySourceConnectivity(
      widget.parentRef,
      PlaylistSourceType.xtream,
      url,
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
    final source = PlaylistSource(
      id: PlaylistSource.generateId(),
      name: name,
      url: url,
      type: PlaylistSourceType.xtream,
      username: user,
      password: pass,
      epgUrl: PlaylistSource.buildXtreamEpgUrl(url, user, pass),
    );
    if (context.mounted) Navigator.pop(context);
    await _addSourceAndSync(
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
    final messenger = ScaffoldMessenger.of(widget.parentContext);

    setState(() {
      _isVerifying = true;
      _error = null;
    });

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
    final source = PlaylistSource(
      id: PlaylistSource.generateId(),
      name: name,
      url: url,
      type: PlaylistSourceType.stalkerPortal,
      macAddress: mac,
    );
    if (context.mounted) Navigator.pop(context);
    await _addSourceAndSync(
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
