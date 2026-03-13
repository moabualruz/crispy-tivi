import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/screen_template.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/utils/stream_url_actions.dart';
import '../../../../core/widgets/context_menu_builders.dart';
import '../../../../core/widgets/context_menu_panel.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_favorites_provider.dart';
import '../providers/vod_providers.dart';
import '../widgets/episode_playback_helper.dart';
import '../widgets/play_next_episode_button.dart';
import '../widgets/series_details_tab.dart';
import '../widgets/series_episodes_tab.dart';
import '../widgets/series_hero_header.dart';
import '../widgets/series_more_like_this_tab.dart';
import '../widgets/series_tab_bar_delegate.dart';
import '../widgets/vod_detail_actions.dart' show CircularAction, RateAction;

export '../widgets/series_details_tab.dart' show SeriesDetailsTab;
export '../widgets/series_episodes_tab.dart' show SeriesEpisodesTab;

/// Detail screen for a TV series.
/// Cinematic series detail layout.
///
/// Features three tabs below the hero header:
/// - Episodes (default): season selector + episode list
/// - More Like This: similar series carousel
/// - Details: cast, genres, description
class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.series});

  final VodItem series;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  /// Local UI state — which season the user has selected.
  ///
  /// `null` means "all seasons / not yet initialised".
  /// Episode data itself lives in [seriesEpisodesProvider].
  int? _selectedSeason;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = widget.series;

    final episodesKey = (seriesId: s.id, sourceId: s.sourceId);
    final episodesAsync = ref.watch(seriesEpisodesProvider(episodesKey));

    // Initialise season selection once data loads — only on first load.
    episodesAsync.whenData((result) {
      if (_selectedSeason == null && result.seasons.isNotEmpty) {
        // Use addPostFrameCallback to avoid setState during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedSeason == null) {
            setState(() => _selectedSeason = result.seasons.first);
          }
        });
      }
    });

    final allEpisodes = episodesAsync.asData?.value.episodes ?? const [];
    final seasons = episodesAsync.asData?.value.seasons ?? const [];
    final filtered =
        _selectedSeason == null
            ? allEpisodes
            : allEpisodes
                .where((e) => e.seasonNumber == _selectedSeason)
                .toList();

    // select() narrows the watch to just this series'
    // membership — other favorite toggles won't rebuild
    // this screen.
    final isFav = ref.watch(
      vodFavoritesProvider.select((st) => st.value?.contains(s.id) ?? false),
    );

    // Shared compact body: the existing tabbed layout.
    Widget buildCompactBody() {
      return NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SeriesHeroHeader(
              series: s,
              isFavorite: isFav,
              onBack: () => context.pop(),
              onToggleFavorite:
                  () => ref
                      .read(vodFavoritesProvider.notifier)
                      .toggleFavorite(s.id),
            ),
            _synopsis(s, isFav, tt, cs),
            if (episodesAsync.hasValue && allEpisodes.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayNextEpisodeButton(
                        episodes: filtered,
                        seriesId: s.id,
                        onPlay: _play,
                      ),
                      const SizedBox(height: CrispySpacing.xs),
                      _AutoplayToggle(),
                    ],
                  ),
                ),
              ),
            SliverPersistentHeader(
              pinned: true,
              delegate: SeriesTabBarDelegate(
                TabBar(
                  indicatorColor: cs.primary,
                  indicatorWeight: 3,
                  labelColor: cs.onSurface,
                  labelStyle: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelColor: cs.onSurfaceVariant,
                  unselectedLabelStyle: tt.labelLarge,
                  dividerColor: cs.outline.withValues(alpha: 0.12),
                  tabs: const [
                    Tab(text: 'Episodes'),
                    Tab(text: 'More Like This'),
                    Tab(text: 'Details'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            SeriesEpisodesTab(
              series: s,
              episodesAsync: episodesAsync,
              seasons: seasons,
              selectedSeason: _selectedSeason,
              filtered: filtered,
              onSeasonChanged: (v) => setState(() => _selectedSeason = v),
              onPlay: _play,
              onEpMenu: _epMenu,
              cs: cs,
              tt: tt,
            ),
            SeriesMoreLikeThisTab(currentSeries: widget.series),
            SeriesDetailsTab(series: widget.series),
          ],
        ),
      );
    }

    // TV wide layout: poster on left, series info + episodes on right.
    Widget buildTvWideBody() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: poster + actions
          SizedBox(
            width: 300,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(CrispySpacing.lg),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SmartImage(
                      itemId: s.id,
                      title: s.name,
                      imageUrl: s.posterUrl,
                      imageKind: 'poster',
                      icon: Icons.tv,
                    ),
                  ),
                  const SizedBox(height: CrispySpacing.md),
                  Text(
                    s.name,
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: CrispySpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularAction(
                        icon: isFav ? Icons.check : Icons.add,
                        label: 'My List',
                        onTap:
                            () => ref
                                .read(vodFavoritesProvider.notifier)
                                .toggleFavorite(s.id),
                      ),
                      const SizedBox(width: CrispySpacing.xl),
                      RateAction(itemId: s.id),
                    ],
                  ),
                  if (s.description != null && s.description!.isNotEmpty) ...[
                    const SizedBox(height: CrispySpacing.md),
                    Text(
                      s.description!,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // Right: season selector + episode list
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (episodesAsync.hasValue && allEpisodes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(CrispySpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayNextEpisodeButton(
                          episodes: filtered,
                          seriesId: s.id,
                          onPlay: _play,
                        ),
                        const SizedBox(height: CrispySpacing.xs),
                        _AutoplayToggle(),
                      ],
                    ),
                  ),
                Expanded(
                  child: SeriesEpisodesTab(
                    series: s,
                    episodesAsync: episodesAsync,
                    seasons: seasons,
                    selectedSeason: _selectedSeason,
                    filtered: filtered,
                    onSeasonChanged: (v) => setState(() => _selectedSeason = v),
                    onPlay: _play,
                    onEpMenu: _epMenu,
                    cs: cs,
                    tt: tt,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: TestKeys.seriesDetailScreen,
        backgroundColor: cs.surface,
        body: ScreenTemplate(
          focusRestorationKey: 'series-detail-${s.id}',
          compactBody: buildCompactBody(),
          largeBody: buildTvWideBody(),
        ),
      ),
    );
  }

  // -- Slivers --

  Widget _synopsis(VodItem s, bool isFav, TextTheme tt, ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.description != null && s.description!.isNotEmpty) ...[
              const SizedBox(height: CrispySpacing.sm),
              Text(
                s.description!,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: CrispySpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularAction(
                  icon: isFav ? Icons.check : Icons.add,
                  label: 'My List',
                  onTap:
                      () => ref
                          .read(vodFavoritesProvider.notifier)
                          .toggleFavorite(widget.series.id),
                ),
                const SizedBox(width: CrispySpacing.xl),
                // FE-VODS-05: Thumbs up / down rating
                RateAction(itemId: s.id),
              ],
            ),
            const SizedBox(height: CrispySpacing.sm),
          ],
        ),
      ),
    );
  }

  // -- Actions --

  void _epMenu(BuildContext ctx, VodItem ep) {
    showContextMenuPanel(
      context: ctx,
      sections: buildEpisodeContextMenu(
        context: ctx,
        episodeName: ep.name,
        colorScheme: Theme.of(ctx).colorScheme,
        onPlay: () => _play(ep),
        onCopyUrl: () => copyStreamUrl(ctx, ep.streamUrl),
        onOpenExternal:
            hasExternalPlayer(ref)
                ? () => openInExternalPlayer(
                  context: ctx,
                  ref: ref,
                  streamUrl: ep.streamUrl,
                  title: ep.name,
                )
                : null,
      ),
    );
  }

  void _play(VodItem ep) {
    final allEpisodes =
        ref
            .read(
              seriesEpisodesProvider((
                seriesId: widget.series.id,
                sourceId: widget.series.sourceId,
              )),
            )
            .asData
            ?.value
            .episodes ??
        const [];
    final filtered =
        _selectedSeason == null
            ? allEpisodes
            : allEpisodes
                .where((e) => e.seasonNumber == _selectedSeason)
                .toList();
    playEpisode(
      context: context,
      ref: ref,
      episode: ep,
      series: widget.series,
      episodeList: filtered,
    );
  }
}

/// Small toggle that lets users enable/disable "Autoplay
/// Next Episode". State is stored via [SettingsNotifier].
class _AutoplayToggle extends ConsumerWidget {
  const _AutoplayToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final autoplay = ref.watch(
      settingsNotifierProvider.select(
        (s) => s.value?.autoplayNextEpisode ?? true,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Autoplay next episode',
          toggled: autoplay,
          child: Switch(
            value: autoplay,
            onChanged:
                (v) => ref
                    .read(settingsNotifierProvider.notifier)
                    .setAutoplayNextEpisode(v),
            activeThumbColor: cs.primary,
          ),
        ),
        const SizedBox(width: CrispySpacing.xs),
        Text(
          'Autoplay Next Episode',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
