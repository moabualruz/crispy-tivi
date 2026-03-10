import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

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
    // Narrow watches via .select() so the tab subtree only
    // rebuilds when its actual inputs change — not on every
    // VodState field flip (e.g. isLoading toggle).
    final isLoading = ref.watch(vodProvider.select((s) => s.isLoading));
    final error = ref.watch(vodProvider.select((s) => s.error));
    final isEmpty = ref.watch(vodProvider.select((s) => s.items.isEmpty));
    final movieCategories = ref.watch(
      vodProvider.select((s) => s.movieCategories),
    );
    final newReleases = ref.watch(vodProvider.select((s) => s.newReleases));

    return VodBrowserShell(
      title: context.l10n.vodMovies,
      isLoading: isLoading,
      error: error,
      isEmpty: isEmpty,
      emptyIcon: Icons.movie_outlined,
      emptyTitle: context.l10n.vodNoItems,
      emptyDescription: 'Add a playlist source in Settings',
      onRetry: () => ref.invalidate(vodProvider),
      child: Scaffold(
        key: TestKeys.vodBrowserScreen,
        appBar: AppBar(
          title: Text(context.l10n.vodMovies),
          actions: [
            IconButton(
              tooltip: context.l10n.homeMyList,
              icon: const Icon(Icons.playlist_add_check_rounded),
              onPressed: () => context.go(AppRoutes.favorites),
            ),
            const AppBarSearchButton(),
          ],
        ),
        body: FocusTraversalGroup(
          child: VodMoviesTab(
            movieCategories: movieCategories,
            newReleases: newReleases,
          ),
        ),
      ),
    );
  }
}
