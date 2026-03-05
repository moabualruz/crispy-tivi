import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/widgets/app_bar_search_button.dart';
import '../providers/vod_providers.dart';
import '../widgets/vod_browser_shell.dart';
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

    return VodBrowserShell(
      title: 'Movies',
      isLoading: state.isLoading,
      error: state.error,
      isEmpty: state.items.isEmpty,
      emptyIcon: Icons.movie_outlined,
      emptyTitle: 'No movies available',
      emptyDescription: 'Add a playlist source in Settings',
      child: Scaffold(
        key: TestKeys.vodBrowserScreen,
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
      ),
    );
  }
}
