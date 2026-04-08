import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/remote_action.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Remote Control settings section: key mappings
/// and reset to defaults.
class RemoteSettingsSection extends ConsumerWidget {
  const RemoteSettingsSection({super.key, required this.remoteKeyMap});

  final Map<int, RemoteAction> remoteKeyMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Remote Control',
          icon: Icons.settings_remote,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.gamepad),
              title: const Text('Key Mappings'),
              subtitle: Text(
                '${remoteKeyMap.length} keys '
                'configured',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRemoteKeyMapScreen(context, ref, remoteKeyMap),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Reset to Defaults'),
              subtitle: const Text('Restore original key assignments'),
              onTap: () => _confirmResetKeyMappings(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  void _showRemoteKeyMapScreen(
    BuildContext context,
    WidgetRef ref,
    Map<int, RemoteAction> keyMap,
  ) {
    // Group by action for display.
    final byAction = <RemoteAction, List<int>>{};
    for (final action in RemoteAction.values) {
      byAction[action] = [];
    }
    for (final entry in keyMap.entries) {
      byAction[entry.value]?.add(entry.key);
    }

    showDialog(
      context: context,
      builder: (_) => _RemoteKeyMapDialog(byAction: byAction),
    );
  }

  void _confirmResetKeyMappings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reset Key Mappings?'),
            content: const Text(
              'This will restore all remote control '
              'keys to their default assignments.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .resetRemoteKeyMappings();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Key mappings reset to defaults'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Reset'),
              ),
            ],
          ),
    );
  }
}

/// Dialog listing all remote actions with their key
/// bindings.
class _RemoteKeyMapDialog extends ConsumerStatefulWidget {
  const _RemoteKeyMapDialog({required this.byAction});

  final Map<RemoteAction, List<int>> byAction;

  @override
  ConsumerState<_RemoteKeyMapDialog> createState() =>
      _RemoteKeyMapDialogState();
}

class _RemoteKeyMapDialogState extends ConsumerState<_RemoteKeyMapDialog> {
  late Map<RemoteAction, List<int>> _byAction;

  @override
  void initState() {
    super.initState();
    _byAction = Map.of(widget.byAction);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Key Mappings'),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      content: SizedBox(
        width: 400,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: RemoteAction.values.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final action = RemoteAction.values[i];
            final keys = _byAction[action] ?? [];
            final keysLabel =
                keys.isEmpty
                    ? 'Not assigned'
                    : keys.map((id) => keyLabel(id)).join(', ');

            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.sm,
              ),
              title: Text(action.label),
              subtitle: Text(
                keysLabel,
                style: TextStyle(
                  color:
                      keys.isEmpty
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.primary,
                ),
              ),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () => _captureKey(action),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  /// Shows a dialog that captures the next key
  /// press.
  void _captureKey(RemoteAction action) {
    showDialog(
      context: context,
      builder:
          (ctx) => _KeyCaptureDialog(
            action: action,
            currentKeys: _byAction[action] ?? [],
            onKeyCaptured: (keyId) {
              // Remove this key from any other action.
              for (final entry in _byAction.entries) {
                entry.value.remove(keyId);
              }
              // Add to this action.
              final keys = _byAction[action] ?? [];
              if (!keys.contains(keyId)) {
                keys.add(keyId);
              }
              setState(() => _byAction[action] = keys);

              // Persist via settings.
              ref
                  .read(settingsNotifierProvider.notifier)
                  .setRemoteKeyMapping(keyId, action);
            },
            onClear: () {
              final keys = List<int>.from(_byAction[action] ?? []);
              for (final keyId in keys) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .removeRemoteKeyMapping(keyId);
              }
              setState(() => _byAction[action] = []);
            },
          ),
    );
  }
}

/// Modal that captures the next key press.
class _KeyCaptureDialog extends StatefulWidget {
  const _KeyCaptureDialog({
    required this.action,
    required this.currentKeys,
    required this.onKeyCaptured,
    required this.onClear,
  });

  final RemoteAction action;
  final List<int> currentKeys;
  final void Function(int keyId) onKeyCaptured;
  final VoidCallback onClear;

  @override
  State<_KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<_KeyCaptureDialog> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentLabel =
        widget.currentKeys.isEmpty
            ? 'None'
            : widget.currentKeys.map((id) => keyLabel(id)).join(', ');

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        widget.onKeyCaptured(event.logicalKey.keyId);
        Navigator.pop(context);
      },
      child: AlertDialog(
        title: Text('Set Key: ${widget.action.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard, size: 48, color: colorScheme.primary),
            const SizedBox(height: CrispySpacing.md),
            const Text(
              'Press any key on your remote\n'
              'or keyboard to assign it.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CrispySpacing.sm),
            Text(
              'Current: $currentLabel',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.currentKeys.isNotEmpty)
            TextButton(
              onPressed: () {
                widget.onClear();
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
