import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import 'home_sections.dart';
import 'my_list_section.dart';
import 'quick_access_row.dart';

/// TV layout for the Home screen.
///
/// Full-width scrollable list of home sections — no detail pane.
class HomeTvLayout extends StatelessWidget {
  /// Creates the home TV layout.
  const HomeTvLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: CustomScrollView(
        slivers: [
          // My List
          const SliverToBoxAdapter(child: MyListSection()),

          // Continue Watching + Cross-Device
          const SliverToBoxAdapter(child: HomeContinueWatchingSection()),

          // Quick Access tiles
          const SliverToBoxAdapter(child: QuickAccessRow()),

          // AI Recommendations
          const SliverToBoxAdapter(child: HomeRecommendationsSection()),

          // Top 10 Today
          const SliverToBoxAdapter(child: HomeTop10Section()),

          // Recent Channels
          SliverToBoxAdapter(child: HomeChannelSection.recent()),

          // Favorite Channels
          SliverToBoxAdapter(child: HomeChannelSection.favorites()),

          // Upcoming Programs
          const SliverToBoxAdapter(child: HomeUpcomingProgramsSection()),

          // Latest Movies
          const SliverToBoxAdapter(child: HomeLatestVodSection()),

          const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xxl)),
        ],
      ),
    );
  }
}
