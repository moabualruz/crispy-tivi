import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/widgets/app_bar_search_button.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/vod_grid_loading_shell.dart';
import '../providers/vod_providers.dart';
import '../widgets/vod_movies_grid.dart' show vodMaxExtent;
import '../widgets/vod_movies_tab.dart';

/// VOD movies browser screen.
///
/// Layout:
/// - Category dropdown filter
/// - Hero banner (featured items)
/// - Grid of poster cards
///
/// Series has been promoted to its own top-level tab
/// ([SeriesBrowserScreen]) per V2 navigation spec.
class VodBrowserScreen extends ConsumerWidget {
  const VodBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vodProvider);

    if (state.isLoading) {
      return _buildLoading(context);
    }
    if (state.error != null) {
      return _buildError(state.error!);
    }
    if (state.items.isEmpty) {
      return _buildEmpty(context, ref);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movies'),
        actions: [
          IconButton(
            tooltip: 'My List',
            icon: const Icon(Icons.playlist_add_check_rounded),
            onPressed: () => context.go(AppRoutes.favorites),
          ),
          const AppBarSearchButton(),
        ],
      ),
      body: FocusTraversalGroup(child: VodMoviesTab(state: state)),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movies')),
      body: VodGridLoadingShell(maxCrossAxisExtent: vodMaxExtent(context)),
    );
  }

  Widget _buildError(String error) {
    return Scaffold(body: ErrorStateWidget(message: 'Failed to load: $error'));
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: EmptyStateWidget(
        icon: Icons.movie_outlined,
        title: 'No movies available',
        description: 'Add a playlist source in Settings',
        showSettingsButton: true,
      ),
    );
  }
}
