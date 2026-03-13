import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import '../screens/favorites_continue_watching.dart';
import '../screens/favorites_my_list.dart';
import '../screens/favorites_recently_watched.dart';
import '../screens/favorites_up_next.dart';
import '../providers/favorites_history_provider.dart';

/// TV master-detail layout for the Favorites/History screen.
///
/// Master panel: tab content from the active tab (My Favorites,
/// Recently Watched, Continue Watching, Up Next).
/// Detail panel: content detail preview or welcome message.
class FavoritesTvLayout extends StatelessWidget {
  /// Creates the favorites TV layout.
  const FavoritesTvLayout({required this.state, super.key});

  /// Current favorites/history state.
  final FavoritesHistoryState state;

  @override
  Widget build(BuildContext context) {
    return TvMasterDetailLayout(
      masterPanel: FocusTraversalGroup(
        child: Column(
          children: [
            const SourceSelectorBar(),
            Expanded(
              child: TabBarView(
                children: [
                  const MyFavoritesTab(),
                  RecentlyWatchedTab(state: state),
                  const ContinueWatchingTab(),
                  const UpNextTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      detailPanel: const _FavoritesDetailPanel(),
    );
  }
}

class _FavoritesDetailPanel extends StatelessWidget {
  const _FavoritesDetailPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: CrispySpacing.md),
          Text(
            'Select an item',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            'Choose a favorite to see details',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
