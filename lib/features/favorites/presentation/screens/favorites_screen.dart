import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/app_bar_search_button.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../providers/favorites_history_provider.dart';
import 'favorites_continue_watching.dart';
import 'favorites_my_list.dart';
import 'favorites_recently_watched.dart';
import 'favorites_up_next.dart';

/// Favorites & History screen.
///
/// Tab 0: My Favorites — favorited channels and VOD items.
/// Tab 1: Recently Watched channels (reverse-chron, sortable).
/// Tab 2: Continue Watching VOD items (partially watched).
/// Tab 3: Up Next — unified queue of in-progress + upcoming (FE-FAV-10).
///
/// FE-FAV-05: AppBar shows a pause/resume toggle for history
/// recording. A "PAUSED" chip is shown in the title area
/// when recording is inactive.
///
/// Large-screen layout (≥ 840 dp): two-column grid per [F-09].
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesHistoryProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final isPaused = settingsAsync.value?.historyRecordingPaused ?? false;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        key: TestKeys.favoritesScreen,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.favoritesTitle),
              if (isPaused) ...[
                const SizedBox(width: CrispySpacing.sm),
                const _HistoryPausedBadge(),
              ],
            ],
          ),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'My Favorites'),
              const Tab(text: 'Recently Watched'),
              Tab(text: context.l10n.vodContinueWatching),
              const Tab(text: 'Up Next'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setHistoryRecordingPaused(!isPaused);
              },
              icon: Icon(
                isPaused
                    ? Icons.history_toggle_off
                    : Icons.manage_history_outlined,
              ),
              tooltip: isPaused ? 'Resume recording' : 'Pause recording',
            ),
            const AppBarSearchButton(),
            if (state.recentlyWatched.isNotEmpty)
              IconButton(
                onPressed: () {
                  ref.read(favoritesHistoryProvider.notifier).clearHistory();
                },
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear history',
              ),
          ],
        ),
        body: Column(
          children: [
            const SourceSelectorBar(),
            Expanded(
              child: FocusTraversalGroup(
                child: TabBarView(
                  children: [
                    const MyFavoritesTab(),
                    RecentlyWatchedTab(state: state),
                    const ContinueWatchingTab(),
                    const UpNextTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FE-FAV-05: Paused history badge ──────────────────────────

/// Small pill badge shown in the [HistoryScreen] title row when
/// history recording is currently paused.
class _HistoryPausedBadge extends StatelessWidget {
  const _HistoryPausedBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(CrispyRadius.full),
      ),
      child: Text(
        'PAUSED',
        style: tt.labelSmall?.copyWith(
          color: cs.onErrorContainer,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
