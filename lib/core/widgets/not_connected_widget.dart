import 'package:flutter/material.dart';

import 'package:crispy_tivi/core/theme/crispy_spacing.dart';

/// Empty state shown when no media server source is connected.
///
/// Presents a [Icons.link_off] icon, a descriptive message, and a
/// "Connect" [FilledButton] that pops the current route so the user
/// can complete the login flow.
///
/// Used by [MediaServerHomeScreen] and [PlexHomeScreen] (and any
/// future media-server home screen that requires the same fallback).
class NotConnectedWidget extends StatelessWidget {
  const NotConnectedWidget({super.key, required this.serverName});

  /// Name of the server shown in the title, e.g. `'Plex'`, `'Emby'`.
  final String serverName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: CrispySpacing.md),
          Text(
            'Not connected to $serverName',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            'Sign in to browse your libraries.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: CrispySpacing.lg),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.login),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
