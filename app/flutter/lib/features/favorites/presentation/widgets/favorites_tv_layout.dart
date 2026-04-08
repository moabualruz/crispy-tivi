import 'package:flutter/material.dart';

import '../../../../core/widgets/source_selector_bar.dart';
import '../screens/favorites_continue_watching.dart';
import '../screens/favorites_my_list.dart';
import '../screens/favorites_recently_watched.dart';
import '../screens/favorites_up_next.dart';
import '../providers/favorites_history_provider.dart';

/// TV layout for the Favorites/History screen.
///
/// Full-width tab content — no detail pane (items navigate
/// directly to their detail screens on selection).
class FavoritesTvLayout extends StatelessWidget {
  /// Creates the favorites TV layout.
  const FavoritesTvLayout({required this.state, super.key});

  /// Current favorites/history state.
  final FavoritesHistoryState state;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
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
    );
  }
}
