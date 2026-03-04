import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/stream_url_actions.dart';
import '../../../../core/widgets/context_menu_builders.dart';
import '../../../../core/widgets/context_menu_panel.dart';
import '../../../../core/widgets/horizontal_scroll_row.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../favorites/presentation/providers/favorites_controller.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../recommendations/domain/entities/recommendation.dart';
import '../../../recommendations/presentation/providers/recommendation_providers.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../../vod/presentation/widgets/continue_watching_section.dart';
import '../../../vod/presentation/widgets/cross_device_section.dart';
import '../providers/home_providers.dart';
import 'channel_list_section.dart';
import 'vod_row.dart';

// ── FE-H-05: Dynamic personalized row labels ────────────

/// Returns a rich label string for a home-screen section based on
/// [type] and optional context data.
///
/// Rules:
/// - `'continue_watching'` — appends item count badge when > 0.
/// - `'recently_added'`   — shows "Added this week · N new" when items
///   were added within the last 7 days; falls back to "Latest Added".
/// - `'recommendations'`  — returns the [dynamicTitle] from the
///   [RecommendationSection] (already computed by the engine).
///
/// All other types return [fallback] unchanged.
String dynamicSectionLabel({
  required String type,
  String fallback = '',
  int count = 0,
  List<VodItem>? items,
}) {
  switch (type) {
    case 'continue_watching':
      if (count <= 0) return fallback;
      return '$fallback · $count item${count == 1 ? '' : 's'}';

    case 'recently_added':
      if (items == null || items.isEmpty) return fallback;
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final recent =
          items
              .where((i) => i.addedAt != null && i.addedAt!.isAfter(cutoff))
              .length;
      if (recent > 0) return 'Added this week · $recent new';
      return fallback;

    default:
      return fallback;
  }
}

/// Shows the channel long-press context menu with
/// favorite-toggle, copy-URL, and external-player actions.
void _showChannelContextMenu(
  BuildContext context,
  WidgetRef ref,
  Channel channel,
) {
  showContextMenuPanel(
    context: context,
    sections: buildChannelContextMenu(
      channelName: channel.name,
      isFavorite: channel.isFavorite,
      colorScheme: Theme.of(context).colorScheme,
      onToggleFavorite:
          () => ref
              .read(favoritesControllerProvider.notifier)
              .toggleFavorite(channel),
      onCopyUrl: () => copyStreamUrl(context, channel.streamUrl),
      onOpenExternal:
          hasExternalPlayer(ref)
              ? () => openInExternalPlayer(
                context: context,
                ref: ref,
                streamUrl: channel.streamUrl,
                title: channel.name,
              )
              : null,
    ),
  );
}

// ── Continue Watching Section ───────────────────────────

/// Watches continue-watching and cross-device providers
/// independently from the rest of the home screen.
class HomeContinueWatchingSection extends ConsumerWidget {
  /// Creates the continue-watching section.
  const HomeContinueWatchingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cwMoviesIdx = ref.watch(continueWatchingMoviesProvider);
    // Use the next-episode-substituted provider so that episodes
    // >= 90% complete surface the NEXT episode to the user.
    final cwSeriesIdx = ref.watch(continueWatchingSeriesNextEpisodeProvider);
    final crossDeviceIdx = ref.watch(crossDeviceWatchingProvider);

    final cwMovies = cwMoviesIdx.asData?.value ?? [];
    final cwSeries = cwSeriesIdx.asData?.value ?? [];
    final crossDeviceItems = crossDeviceIdx.asData?.value ?? [];
    final allContinueWatching = [...cwMovies, ...cwSeries]
      ..sort((a, b) => b.lastWatched.compareTo(a.lastWatched));

    // FE-H-05: dynamic label — "Continue Watching · 3 items".
    final cwTitle = dynamicSectionLabel(
      type: 'continue_watching',
      fallback: 'Continue Watching',
      count: allContinueWatching.length,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (allContinueWatching.isNotEmpty)
          ContinueWatchingSection(
            title: cwTitle,
            icon: Icons.play_circle_outline,
            items: allContinueWatching,
            onSeeAll: () => context.go(AppRoutes.favorites),
          ),
        if (crossDeviceItems.isNotEmpty)
          CrossDeviceSection(items: crossDeviceItems),
      ],
    );
  }
}

// ── Recommendations Section ─────────────────────────────

/// Watches recommendation providers independently.
///
/// FE-H-08: Supports "Not interested" long-press on each card.
/// Dismissed item IDs are stored in [dismissedRecommendationsProvider]
/// for the session duration. A "Removed" snackbar with an Undo action
/// is shown after dismissal.
class HomeRecommendationsSection extends ConsumerWidget {
  /// Creates the recommendations section.
  const HomeRecommendationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recSections = ref.watch(recommendationSectionsProvider);
    // FE-H-08: read dismissed IDs to filter out hidden cards.
    final dismissed = ref.watch(dismissedRecommendationsProvider);

    return recSections.when(
      data: (sections) {
        // Filter out dismissed items from each section.
        final visible =
            sections
                .map(
                  (s) => RecommendationSection(
                    title: s.title,
                    reasonType: s.reasonType,
                    dynamicTitle: s.dynamicTitle,
                    items:
                        s.items
                            .where((i) => !dismissed.contains(i.itemId))
                            .toList(),
                  ),
                )
                .where((s) => s.items.isNotEmpty)
                .toList();

        if (visible.isEmpty) return const SizedBox.shrink();

        return _DismissableRecommendationSections(sections: visible);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Renders recommendation swimlanes with per-card "Not interested"
/// long-press support (FE-H-08).
///
/// Each card's long-press shows a bottom sheet with one action:
/// "Not interested". Tapping it calls
/// [DismissedRecommendationsNotifier.dismiss] and shows a snackbar
/// with an Undo button.
class _DismissableRecommendationSections extends ConsumerWidget {
  const _DismissableRecommendationSections({required this.sections});

  final List<RecommendationSection> sections;

  static IconData _iconFor(RecommendationReasonType type) {
    switch (type) {
      case RecommendationReasonType.becauseYouWatched:
        return Icons.history;
      case RecommendationReasonType.popularInGenre:
        return Icons.local_fire_department;
      case RecommendationReasonType.trending:
        return Icons.trending_up;
      case RecommendationReasonType.newForYou:
        return Icons.new_releases;
      case RecommendationReasonType.topPick:
        return Icons.auto_awesome;
      case RecommendationReasonType.coldStart:
        return Icons.explore;
    }
  }

  /// Shows a compact action sheet for the "Not interested" action.
  ///
  /// On confirm, dismisses [itemId] and shows a snackbar with Undo.
  void _showNotInterestedSheet(
    BuildContext context,
    WidgetRef ref,
    String itemId,
    String itemName,
  ) {
    // FE-H-08: bottom sheet with "Not interested" action.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CrispyRadius.md),
        ),
      ),
      builder:
          (sheetCtx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: CrispySpacing.sm),
                // Drag handle.
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      sheetCtx,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(CrispyRadius.full),
                  ),
                ),
                const SizedBox(height: CrispySpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.md,
                  ),
                  child: Text(
                    itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetCtx).textTheme.titleSmall,
                  ),
                ),
                const Divider(height: CrispySpacing.lg),
                ListTile(
                  leading: Icon(
                    Icons.thumb_down_off_alt_outlined,
                    color: Theme.of(sheetCtx).colorScheme.onSurface,
                  ),
                  title: const Text('Not interested'),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    // FE-H-08: dismiss the item.
                    ref
                        .read(dismissedRecommendationsProvider.notifier)
                        .dismiss(itemId);
                    // Show snackbar with Undo.
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Removed from recommendations'),
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed:
                              () => ref
                                  .read(
                                    dismissedRecommendationsProvider.notifier,
                                  )
                                  .undoDismiss(itemId),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: CrispySpacing.sm),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children:
          sections.map((section) {
            final items =
                section.items
                    .map(
                      (rec) => VodItem(
                        id: rec.itemId,
                        name: rec.itemName,
                        streamUrl: rec.streamUrl ?? '',
                        type: VodTypeConversion.fromMediaType(rec.mediaType),
                        posterUrl: rec.posterUrl,
                        category: rec.category,
                        rating: rec.rating,
                        year: rec.year,
                        seriesId: rec.seriesId,
                      ),
                    )
                    .toList();

            if (items.isEmpty) return const SizedBox.shrink();

            // Build a lookup map rec.itemId → Recommendation for the
            // long-press handler.
            final recMap = {for (final r in section.items) r.itemId: r};

            return VodRow(
              key: PageStorageKey(section.title),
              title: section.displayTitle,
              icon: _iconFor(section.reasonType),
              items: items,
              isTitleBadge: true,
              // FE-H-08: long-press shows "Not interested" sheet.
              overlayBuilder: (ctx, vodItem) {
                // Render the "Not interested" trigger on long-press
                // via a GestureDetector layered over the card area.
                final rec = recMap[vodItem.id];
                if (rec == null) {
                  return const Positioned(
                    top: 0,
                    left: 0,
                    child: SizedBox.shrink(),
                  );
                }
                return Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPress:
                        () => _showNotInterestedSheet(
                          context,
                          ref,
                          rec.itemId,
                          rec.itemName,
                        ),
                  ),
                );
              },
            );
          }).toList(),
    );
  }
}

// ── Unified Home Channel Section ────────────────────────

/// Parameterized home-screen channel row.
///
/// Watches [channelsProvider] and renders a [ChannelListSection]
/// when channels are available. Shows nothing on error or empty data.
///
/// FE-H-06: EPG overlay is applied to every tile via
/// [ChannelListSection.epgData]. The overlay shows the current
/// programme title with a semi-transparent scrim and a thin
/// progress bar. Only rendered when EPG data is available.
///
/// Use the named factories [HomeChannelSection.recent] and
/// [HomeChannelSection.favorites] for the standard home-screen rows.
class HomeChannelSection extends ConsumerWidget {
  const HomeChannelSection._({
    required String title,
    required IconData icon,
    required AsyncValue<List<Channel>> Function(WidgetRef) watch,
    required String seeAllRoute,
    required bool showLoadingIndicator,
    super.key,
  }) : _title = title,
       _icon = icon,
       _watch = watch,
       _seeAllRoute = seeAllRoute,
       _showLoadingIndicator = showLoadingIndicator;

  /// Creates a recent-channels section for the home screen.
  factory HomeChannelSection.recent({Key? key}) => HomeChannelSection._(
    title: 'Recent Channels',
    icon: Icons.history,
    watch: (ref) => ref.watch(recentChannelsProvider),
    seeAllRoute: AppRoutes.tv,
    showLoadingIndicator: true,
    key: key,
  );

  /// Creates a favorite-channels section for the home screen.
  factory HomeChannelSection.favorites({Key? key}) => HomeChannelSection._(
    title: 'Your Favorites',
    icon: Icons.star,
    watch: (ref) => ref.watch(favoriteChannelsProvider),
    seeAllRoute: AppRoutes.favorites,
    showLoadingIndicator: false,
    key: key,
  );

  final String _title;
  final IconData _icon;

  /// Callback that watches the appropriate channels provider.
  final AsyncValue<List<Channel>> Function(WidgetRef) _watch;

  /// Route pushed when the "See all" button is tapped.
  final String _seeAllRoute;

  /// Whether to show a [LinearProgressIndicator] while loading.
  /// Recent-channels row shows one; favorites row hides silently.
  final bool _showLoadingIndicator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = _watch(ref);
    final epgState = ref.watch(epgProvider);

    return channelsAsync.when(
      data:
          (channels) =>
              channels.isNotEmpty
                  ? ChannelListSection(
                    title: _title,
                    icon: _icon,
                    channels: channels,
                    // FE-H-06: pass now-playing map — tiles show EPG overlay.
                    epgData: _buildNowPlayingMap(channels, epgState),
                    onChannelLongPress:
                        (channel) =>
                            _showChannelContextMenu(context, ref, channel),
                    onSeeAll: () => context.go(_seeAllRoute),
                  )
                  : const SizedBox.shrink(),
      loading:
          () =>
              _showLoadingIndicator
                  ? const LinearProgressIndicator()
                  : const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Builds a map of currently-airing EPG entries keyed by channel EPG ID.
///
/// Uses [channel.tvgId] as the lookup key (falling back to [channel.id])
/// because EPG entries are indexed by tvg-id in [EpgState.entries].
/// Returns null when [epgState] has no loaded entries — callers treat
/// null the same as an empty map (no overlay rendered).
Map<String, EpgEntry>? _buildNowPlayingMap(
  List<Channel> channels,
  EpgState epgState,
) {
  if (epgState.entries.isEmpty) return null;
  final result = <String, EpgEntry>{};
  for (final channel in channels) {
    final epgKey = channel.tvgId ?? channel.id;
    final entry = epgState.getNowPlaying(epgKey);
    if (entry != null) result[epgKey] = entry;
  }
  return result.isEmpty ? null : result;
}

// ── Latest VOD Section ──────────────────────────────────

/// Watches latest VOD provider independently.
class HomeLatestVodSection extends ConsumerWidget {
  /// Creates the latest-VOD section.
  const HomeLatestVodSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestVodProvider);

    if (latest.isEmpty) return const SizedBox.shrink();

    // FE-H-05: dynamic label — "Added this week · 12 new" when
    // items were added within the last 7 days.
    final latestTitle = dynamicSectionLabel(
      type: 'recently_added',
      fallback: 'Latest Added',
      items: latest,
    );

    return VodRow(
      title: latestTitle,
      icon: Icons.new_releases,
      items: latest,
      isTitleBadge: true,
      onSeeAll: () => context.go(AppRoutes.vod),
    );
  }
}

// ── Top 10 Section ──────────────────────────────────────

/// Top 10 ranked row with large outlined
/// numbers and portrait poster cards.
class HomeTop10Section extends ConsumerWidget {
  /// Creates the Top 10 section.
  const HomeTop10Section({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top10 = ref.watch(top10VodProvider);

    if (top10.isEmpty) return const SizedBox.shrink();

    return VodRow(
      title: 'Top 10 Today',
      icon: Icons.auto_awesome,
      items: top10,
      showRank: true,
      isTitleBadge: true,
      onSeeAll: () => context.go(AppRoutes.vod),
    );
  }
}

// ── Upcoming Programs Section (FE-H-07) ─────────────────

/// Horizontal row of programmes starting within 120 minutes
/// across the user's favorite channels.
///
/// Only rendered when both favorite channels and EPG data
/// are loaded and at least one upcoming entry exists.
class HomeUpcomingProgramsSection extends ConsumerWidget {
  /// Creates the upcoming-programs section.
  const HomeUpcomingProgramsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingProgramsProvider);

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return HorizontalScrollRow<UpcomingProgram>(
      items: upcoming,
      itemWidth: 200,
      sectionHeight: 120,
      headerIcon: Icons.schedule,
      headerTitle: 'Up Next on Your Favorites',
      itemSpacing: CrispySpacing.sm,
      itemBuilder: (ctx, program, _) {
        return _UpcomingProgramCard(program: program);
      },
    );
  }
}

/// A single card in the upcoming-programs row showing the channel
/// logo, programme title, start time, and optional genre chip.
///
/// Tapping navigates to the EPG timeline pre-scrolled to the
/// programme's start time, letting the user set a reminder or
/// browse the surrounding schedule.
class _UpcomingProgramCard extends ConsumerWidget {
  const _UpcomingProgramCard({required this.program});

  final UpcomingProgram program;

  /// Format [DateTime] as HH:MM using local time.
  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final channel = program.channel;
    final entry = program.entry;
    final startLabel = _formatTime(entry.startTime);

    return GestureDetector(
      onTap: () {
        // Pre-position the EPG timeline to the programme's start
        // time, then navigate — gives a seamless "jump to timeslot"
        // experience without needing extra query parameters.
        ref
            .read(epgProvider.notifier)
            .setFocusedTime(entry.startTime.toLocal());
        context.go(AppRoutes.epg);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CrispyRadius.sm),
        child: ColoredBox(
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              // Channel logo thumbnail.
              SizedBox(
                width: 64,
                height: double.infinity,
                child: SmartImage(
                  itemId: channel.id,
                  title: channel.name,
                  imageUrl: channel.logoUrl,
                  imageKind: 'logo',
                  fit: BoxFit.contain,
                  icon: Icons.tv,
                  memCacheWidth: 128,
                ),
              ),
              // Programme info.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.sm,
                    vertical: CrispySpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: CrispySpacing.xxs),
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: CrispySpacing.xxs),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 10, color: cs.primary),
                          const SizedBox(width: CrispySpacing.xxs),
                          Text(
                            startLabel,
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Genre chip — only shown when category is available.
                          if (entry.category != null &&
                              entry.category!.isNotEmpty) ...[
                            const SizedBox(width: CrispySpacing.xs),
                            _GenreChip(label: entry.category!),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact genre label chip shown on upcoming programme cards.
///
/// Uses [ColorScheme.secondaryContainer] to stay subtle while
/// remaining readable against both light and dark surfaces.
class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(CrispyRadius.xs),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSecondaryContainer,
          fontSize: 9,
        ),
      ),
    );
  }
}
