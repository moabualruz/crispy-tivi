import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_state.dart' show kGlobalEpgUrlKey;
import '../providers/settings_service_providers.dart';

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
