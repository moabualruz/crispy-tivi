import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/app_bar_search_button.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
import '../../../vod/presentation/widgets/vod_hero_banner.dart';
import '../widgets/home_sections.dart';
import '../widgets/my_list_section.dart';
import '../widgets/quick_access_row.dart';

/// Home screen -- the default landing page after profile
/// selection. Shows Continue Watching, Recommendations,
/// Favorite Channels, and Quick Access tiles for features
/// like Media Servers, DVR, and Multiview.
class HomeScreen extends ConsumerWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredItems = ref.watch(vodProvider.select((s) => s.featured));

    return Scaffold(
      appBar: AppBar(
        title: const Text('CrispyTivi'),
        actions: [
          const AppBarSearchButton(),
          IconButton(
            key: const ValueKey('home_favorites_btn'),
            icon: const Icon(Icons.favorite_border_rounded),
            tooltip: 'Favorites',
            onPressed: () => context.go(AppRoutes.favorites),
          ),
        ],
      ),
      body: FocusTraversalGroup(
        child: CustomScrollView(
          slivers: [
            // 1. Hero Banner
            if (featuredItems.isNotEmpty)
              SliverToBoxAdapter(child: VodHeroBanner(items: featuredItems)),

            // 1b. My List (FE-H-01) — hidden when empty
            const SliverToBoxAdapter(child: MyListSection()),

            // 2. Continue Watching + Cross-Device (H-09: above Quick Access)
            const SliverToBoxAdapter(child: HomeContinueWatchingSection()),

            // 3. Quick Access tiles
            const SliverToBoxAdapter(child: QuickAccessRow()),

            // 4. AI Recommendations
            const SliverToBoxAdapter(child: HomeRecommendationsSection()),

            // 5. Top 10 Today
            const SliverToBoxAdapter(child: HomeTop10Section()),

            // 6. Recent Channels
            SliverToBoxAdapter(child: HomeChannelSection.recent()),

            // 7. Favorite Channels
            SliverToBoxAdapter(child: HomeChannelSection.favorites()),

            // 8. Upcoming Programs on favorite channels (FE-H-07)
            const SliverToBoxAdapter(child: HomeUpcomingProgramsSection()),

            // 9. Latest Movies
            const SliverToBoxAdapter(child: HomeLatestVodSection()),

            const SliverToBoxAdapter(
              child: SizedBox(height: CrispySpacing.xxl),
            ),
          ],
        ),
      ),
    );
  }
}
