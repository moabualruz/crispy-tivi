import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/device_form_factor.dart';
import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/widgets/app_bar_search_button.dart';
import '../../../../core/widgets/screen_template.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../iptv/application/playlist_sync_service.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
import '../../../vod/presentation/widgets/vod_hero_banner.dart';
import '../widgets/home_sections.dart';
import '../widgets/home_tv_layout.dart';
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
      key: TestKeys.homeScreen,
      appBar: AppBar(
        title: const Text('CrispyTivi'),
        actions: [
          const AppBarSearchButton(),
          IconButton(
            key: TestKeys.homeFavoritesButton,
            icon: const Icon(Icons.favorite_border_rounded),
            tooltip: context.l10n.commonFavorites,
            onPressed: () => context.go(AppRoutes.favorites),
          ),
        ],
      ),
      body: ScreenTemplate(
        focusRestorationKey: 'home',
        compactBody: _wrapRefresh(
          ref,
          CustomScrollView(
            key: const PageStorageKey('home'),
            slivers: [
              // 0. Source filter bar (hidden when ≤1 source)
              const SliverToBoxAdapter(child: SourceSelectorBar()),

              // 1. Hero Banner
              if (featuredItems.isNotEmpty)
                SliverToBoxAdapter(
                  key: TestKeys.heroBanner,
                  child: VodHeroBanner(items: featuredItems),
                ),

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
        largeBody: const HomeTvLayout(),
      ),
    );
  }

  /// Wraps [child] in [RefreshIndicator] on mobile/tablet.
  Widget _wrapRefresh(WidgetRef ref, Widget child) {
    if (!DeviceFormFactorService.current.isMobile) return child;
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(playlistSyncServiceProvider).syncAll();
      },
      child: child,
    );
  }
}
