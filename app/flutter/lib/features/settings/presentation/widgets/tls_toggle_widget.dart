import 'package:flutter/material.dart';

/// Reusable TLS certificate validation toggle.
///
/// Shows a [SwitchListTile] with title "Accept self-signed certificates"
/// and subtitle explaining the security implications. When toggling ON
/// (disabling TLS validation), shows a confirmation [AlertDialog]
/// warning the user about interception risks. Toggling OFF (enabling
/// TLS validation) applies immediately without confirmation.
///
/// Used in both the global Settings screen and the per-source
/// edit dialog.
class TlsToggleWidget extends StatelessWidget {
  /// Creates a TLS toggle widget.
  const TlsToggleWidget({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Whether self-signed certificates are currently accepted.
  final bool value;

  /// Called when the toggle value changes.
  ///
  /// Only invoked after user confirms the warning dialog when
  /// enabling (setting to `true`). Invoked immediately when
  /// disabling (setting to `false`).
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Accept self-signed certificates'),
      subtitle: const Text(
        'Allows connections to servers with '
        'invalid TLS certificates',
      ),
      secondary: Icon(
        value ? Icons.lock_open : Icons.lock_outline,
        color:
            value
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
      ),
      value: value,
      onChanged: (newValue) {
        if (newValue) {
          // Disabling TLS validation — show confirmation dialog.
          _showConfirmationDialog(context);
        } else {
          // Enabling TLS validation — apply immediately.
          onChanged(false);
        }
      },
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.error,
              size: 32,
            ),
            title: const Text('Security Warning'),
            content: const Text(
              'This makes connections vulnerable to '
              'interception. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onChanged(true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
    );
  }
}
