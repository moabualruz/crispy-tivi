import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/core/widgets/loading_state_widget.dart';
import 'package:crispy_tivi/core/widgets/not_connected_widget.dart';

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
              : NotConnectedWidget(serverName: serverName),
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
      loading: () => const LoadingStateWidget(),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
