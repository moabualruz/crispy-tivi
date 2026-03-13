import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import 'home_sections.dart';
import 'my_list_section.dart';
import 'quick_access_row.dart';

/// TV master-detail layout for the Home screen.
///
/// Master panel: scrollable list of home sections (categories).
/// Detail panel: welcome message (no selection state on home).
class HomeTvLayout extends StatelessWidget {
  /// Creates the home TV layout.
  const HomeTvLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const TvMasterDetailLayout(
      masterPanel: _HomeMasterPanel(),
      detailPanel: _HomeDetailPanel(),
    );
  }
}

class _HomeMasterPanel extends StatelessWidget {
  const _HomeMasterPanel();

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

class _HomeDetailPanel extends StatelessWidget {
  const _HomeDetailPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.home_rounded,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: CrispySpacing.md),
          Text(
            'Welcome to CrispyTivi',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            'Browse content from the sections on the left',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
