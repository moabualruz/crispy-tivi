import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';

/// Shared scaffold for Emby, Jellyfin, and Plex home screens.
///
/// Handles the common AppBar (server name + settings action),
/// the "Not connected" fallback, and the loading/error/data
/// states from [librariesProvider].
///
/// The server-specific layout (horizontal list vs grid) is
/// delegated to [libraryListBuilder].
class MediaServerHomeScreen extends ConsumerWidget {
  const MediaServerHomeScreen({
    super.key,
    required this.serverName,
    required this.isConnected,
    required this.librariesProvider,
    required this.libraryListBuilder,
  });

  /// Display title shown in the AppBar.
  ///
  /// Callers pass `source?.displayName ?? 'Fallback'`.
  final String serverName;

  /// Whether a source is currently configured and connected.
  ///
  /// When false, a "Not connected" message is shown instead of libraries.
  final bool isConnected;

  /// Provider that fetches the library items for this server.
  final FutureProvider<List<MediaItem>> librariesProvider;

  /// Builds the server-specific layout (grid, horizontal list, etc.)
  /// from the resolved list of libraries.
  ///
  /// Called only when [librariesProvider] has data and the list is non-empty.
  final Widget Function(List<MediaItem> libraries) libraryListBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: TestKeys.mediaServerHomeScreen,
      appBar: AppBar(
        title: Text(serverName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body:
          isConnected
              ? _LibraryBody(
                librariesProvider: librariesProvider,
                libraryListBuilder: libraryListBuilder,
              )
              : _NotConnectedState(serverName: serverName),
    );
  }
}

/// Proper empty state shown when no source is connected.
///
/// Presents an icon, a descriptive message, and a "Connect" action
/// that pops the screen so the user can use the login flow.
class _NotConnectedState extends StatelessWidget {
  const _NotConnectedState({required this.serverName});

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

class _LibraryBody extends ConsumerWidget {
  const _LibraryBody({
    required this.librariesProvider,
    required this.libraryListBuilder,
  });

  final FutureProvider<List<MediaItem>> librariesProvider;
  final Widget Function(List<MediaItem> libraries) libraryListBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final librariesAsync = ref.watch(librariesProvider);

    return librariesAsync.when(
      data: (libraries) {
        if (libraries.isEmpty) {
          return const Center(child: Text('No libraries found'));
        }
        return libraryListBuilder(libraries);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
