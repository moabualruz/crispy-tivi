import 'package:crispy_tivi/core/theme/crispy_shell_controls.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_icons.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/data/playback_session_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/media/media_presentation_state.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/feature_hero.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/section_selector.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_controls.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/section_shelf.dart';
import 'package:flutter/material.dart';

class MediaView extends StatelessWidget {
  const MediaView({
    required this.state,
    required this.runtime,
    required this.onSelectScope,
    required this.onSelectSeriesSeasonIndex,
    required this.onSelectSeriesEpisodeIndex,
    required this.onLaunchSeriesEpisode,
    required this.onLaunchPlayer,
    required this.onToggleWatchlist,
    required this.watchlistContentKeys,
    super.key,
  });

  final MediaPresentationState state;
  final MediaRuntimeSnapshot runtime;
  final ValueChanged<MediaScope> onSelectScope;
  final ValueChanged<int> onSelectSeriesSeasonIndex;
  final ValueChanged<int> onSelectSeriesEpisodeIndex;
  final VoidCallback onLaunchSeriesEpisode;
  final ValueChanged<PlayerSession> onLaunchPlayer;
  final ValueChanged<String> onToggleWatchlist;
  final List<String> watchlistContentKeys;

  @override
  Widget build(BuildContext context) {
    if (!state.hasContent) {
      return DecoratedBox(
        decoration: CrispyShellRoles.panelDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(CrispyOverhaulTokens.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'No media libraries yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: CrispyOverhaulTokens.small),
              Text(
                'Movies and series appear after a provider imports media catalogs.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: CrispyOverhaulTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final bool movies = state.movies;
    return ListView(
      key: const Key('media-list-view'),
      padding: EdgeInsets.zero,
      children: <Widget>[
        SectionSelector<MediaScope>(
          title: movies ? 'Film scope' : 'Series scope',
          values: state.availableScopes,
          selected: state.scope,
          labelBuilder: (MediaScope value) => value.label,
          keyBuilder: (MediaScope value) => 'media-scope-${value.name}',
          onSelect: onSelectScope,
        ),
        const SizedBox(height: CrispyOverhaulTokens.small),
        if (movies) ...<Widget>[
          _MediaLeadRow(state: state, movies: movies),
          const SizedBox(height: CrispyOverhaulTokens.section),
          _MovieDetailCard(
            key: const Key('movie-detail-card'),
            feature: state.movieHero,
            featuredFilm: state.topFilms.first,
            runtime: runtime,
            onLaunchPlayer: onLaunchPlayer,
            onToggleWatchlist: onToggleWatchlist,
            watchlistContentKeys: watchlistContentKeys,
          ),
          const SizedBox(height: CrispyOverhaulTokens.section),
          SectionShelf(
            title: _shelfTitle(movies, state.scope),
            items: state.topFilms,
            showRank: true,
          ),
          const SizedBox(height: CrispyOverhaulTokens.section),
          SectionShelf(
            title: 'Continue Watching Films',
            items: state.continueWatching,
          ),
        ] else ...<Widget>[
          _SeriesDetailPanel(
            key: const Key('series-detail-panel'),
            detail: state.seriesDetail,
            runtime: runtime,
            selectedSeasonIndex: state.seriesSeasonIndex,
            selectedEpisodeIndex: state.seriesEpisodeIndex,
            launchedEpisodeIndex: state.launchedSeriesEpisodeIndex,
            onSelectSeasonIndex: onSelectSeriesSeasonIndex,
            onSelectEpisodeIndex: onSelectSeriesEpisodeIndex,
            onLaunchEpisode: () {
              onLaunchSeriesEpisode();
              onLaunchPlayer(
                _buildSeriesPlayerSession(
                  detail: state.seriesDetail,
                  runtime: runtime,
                  selectedSeasonIndex: state.seriesSeasonIndex,
                  selectedEpisodeIndex: state.seriesEpisodeIndex,
                ),
              );
            },
          ),
          const SizedBox(height: CrispyOverhaulTokens.section),
          _MediaLeadRow(state: state, movies: movies),
          const SizedBox(height: CrispyOverhaulTokens.section),
          _MediaFocusCard(state: state, movies: movies),
          const SizedBox(height: CrispyOverhaulTokens.section),
          SectionShelf(title: 'Next Up Series', items: state.continueWatching),
          const SizedBox(height: CrispyOverhaulTokens.section),
          SectionShelf(
            title: _shelfTitle(movies, state.scope),
            items: state.topSeries,
            showRank: true,
          ),
        ],
      ],
    );
  }
}

class _MediaLeadRow extends StatelessWidget {
  const _MediaLeadRow({required this.state, required this.movies});

  final MediaPresentationState state;
  final bool movies;

  @override
  Widget build(BuildContext context) {
    final HeroFeature feature = movies ? state.movieHero : state.seriesHero;
    final Widget focusCard = _MediaFocusCard(state: state, movies: movies);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: movies ? 7 : 5, child: FeatureHero(feature: feature)),
        const SizedBox(width: CrispyOverhaulTokens.large),
        Expanded(flex: movies ? 5 : 7, child: focusCard),
      ],
    );
  }
}

class _MediaFocusCard extends StatelessWidget {
  const _MediaFocusCard({required this.state, required this.movies});

  final MediaPresentationState state;
  final bool movies;

  @override
  Widget build(BuildContext context) {
    final HeroFeature feature = movies ? state.movieHero : state.seriesHero;
    final List<_MediaDetailLine> lines =
        movies
            ? <_MediaDetailLine>[
              const _MediaDetailLine(
                label: 'Focus',
                value: 'Featured films lead.',
              ),
              const _MediaDetailLine(
                label: 'Continue',
                value: 'Resume from the shelf.',
              ),
              const _MediaDetailLine(
                label: 'Browse',
                value: 'Scope narrows second.',
              ),
            ]
            : <_MediaDetailLine>[
              const _MediaDetailLine(
                label: 'Focus',
                value: 'Episodes lead first.',
              ),
              const _MediaDetailLine(
                label: 'Continue',
                value: 'Next up stays visible.',
              ),
              const _MediaDetailLine(
                label: 'Browse',
                value: 'Series context leads.',
              ),
            ];

    return DecoratedBox(
      decoration: CrispyShellRoles.infoPlateDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              movies ? 'Films' : 'Series',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: CrispyOverhaulTokens.compact),
            Text(
              movies ? 'Featured films' : 'Series focus',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            Text(
              feature.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              feature.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            ...lines.map(
              (_MediaDetailLine line) => Padding(
                padding: const EdgeInsets.only(
                  bottom: CrispyOverhaulTokens.medium,
                ),
                child: _MediaDetailRow(line: line),
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MediaActionSurface(
                    label: feature.primaryAction,
                    selected: true,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                Expanded(
                  child: _MediaActionSurface(
                    label: feature.secondaryAction,
                    selected: false,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesDetailPanel extends StatelessWidget {
  const _SeriesDetailPanel({
    super.key,
    required this.detail,
    required this.runtime,
    required this.selectedSeasonIndex,
    required this.selectedEpisodeIndex,
    required this.launchedEpisodeIndex,
    required this.onSelectSeasonIndex,
    required this.onSelectEpisodeIndex,
    required this.onLaunchEpisode,
  });

  final SeriesDetailContent detail;
  final MediaRuntimeSnapshot runtime;
  final int selectedSeasonIndex;
  final int selectedEpisodeIndex;
  final int? launchedEpisodeIndex;
  final ValueChanged<int> onSelectSeasonIndex;
  final ValueChanged<int> onSelectEpisodeIndex;
  final VoidCallback onLaunchEpisode;

  @override
  Widget build(BuildContext context) {
    final SeriesSeasonDetail selectedSeason =
        detail.seasons[selectedSeasonIndex];
    final SeriesEpisodeDetail selectedEpisode =
        selectedSeason.episodes[selectedEpisodeIndex];
    final bool launchReady = launchedEpisodeIndex == selectedEpisodeIndex;

    return DecoratedBox(
      decoration: CrispyShellRoles.infoPlateDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              detail.summaryTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: CrispyOverhaulTokens.compact),
            Text(
              detail.summaryBody,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            SectionSelector<int>(
              title: 'Seasons',
              values: List<int>.generate(
                detail.seasons.length,
                (int index) => index,
              ),
              selected: selectedSeasonIndex,
              labelBuilder: (int index) => detail.seasons[index].label,
              keyBuilder: (int index) => 'series-season-$index',
              onSelect: onSelectSeasonIndex,
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            Text(
              selectedSeason.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.medium),
            Text(
              launchReady
                  ? 'Playing ${selectedEpisode.code}.'
                  : 'Ready for ${selectedEpisode.code}.',
              key: const Key('series-handoff-state'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CrispyOverhaulTokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.medium),
            Wrap(
              spacing: CrispyOverhaulTokens.small,
              runSpacing: CrispyOverhaulTokens.small,
              children: <Widget>[
                for (
                  int index = 0;
                  index < selectedSeason.episodes.length;
                  index++
                )
                  _SeriesEpisodeButton(
                    episode: selectedSeason.episodes[index],
                    selected: index == selectedEpisodeIndex,
                    itemKey: Key('series-episode-$selectedSeasonIndex-$index'),
                    onPressed: () => onSelectEpisodeIndex(index),
                  ),
              ],
            ),
            const SizedBox(height: CrispyOverhaulTokens.medium),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ShellControlButton(
                controlKey: const Key('series-launch-action'),
                label:
                    launchReady ? 'Playing now' : selectedEpisode.handoffLabel,
                icon: CrispyShellIcons.contentAction(
                  launchReady ? 'Playing now' : selectedEpisode.handoffLabel,
                ),
                onPressed: onLaunchEpisode,
                controlRole: ShellControlRole.action,
                presentation: ShellControlPresentation.iconAndText,
                emphasis: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesEpisodeButton extends StatelessWidget {
  const _SeriesEpisodeButton({
    required this.episode,
    required this.selected,
    required this.itemKey,
    required this.onPressed,
  });

  final SeriesEpisodeDetail episode;
  final bool selected;
  final Key itemKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShellControlButton(
      controlKey: itemKey,
      label: '${episode.code} ${episode.title}',
      onPressed: onPressed,
      controlRole: ShellControlRole.selector,
      presentation: ShellControlPresentation.textOnly,
      selected: selected,
      contentAlignment: AlignmentDirectional.centerStart,
      expandLabelRow: true,
    );
  }
}

class _MovieDetailCard extends StatelessWidget {
  const _MovieDetailCard({
    required this.feature,
    required this.featuredFilm,
    required this.runtime,
    required this.onLaunchPlayer,
    required this.onToggleWatchlist,
    required this.watchlistContentKeys,
    super.key,
  });

  final HeroFeature feature;
  final ShelfItem featuredFilm;
  final MediaRuntimeSnapshot runtime;
  final ValueChanged<PlayerSession> onLaunchPlayer;
  final ValueChanged<String> onToggleWatchlist;
  final List<String> watchlistContentKeys;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MediaRuntimeItemSnapshot? playbackItem = _findMoviePlaybackItem(
      runtime,
      featuredFilm.title,
    );
    final String contentKey =
        playbackItem?.playbackSource?.contentKey ?? featuredFilm.title;
    final bool watchlisted = watchlistContentKeys.contains(contentKey);
    return DecoratedBox(
      decoration: CrispyShellRoles.infoPlateDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Movie detail', style: textTheme.titleLarge),
            const SizedBox(height: CrispyOverhaulTokens.compact),
            Text(
              'Featured film focus.',
              style: textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            Text(
              feature.title,
              style: textTheme.headlineSmall?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.small),
            Text(
              feature.summary,
              style: textTheme.bodyLarge?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            _MediaDetailRow(
              line: const _MediaDetailLine(
                label: 'Focus',
                value: 'Selected from the top film shelf.',
              ),
            ),
            _MediaDetailRow(
              line: _MediaDetailLine(
                label: 'Selected',
                value: '${featuredFilm.title} · ${featuredFilm.caption}',
              ),
            ),
            const _MediaDetailRow(
              line: _MediaDetailLine(
                label: 'Playback',
                value: 'Open player from detail.',
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MediaActionSurface(
                    key: const Key('movie-player-launch'),
                    label: 'Play movie',
                    selected: true,
                    onTap:
                        () => onLaunchPlayer(
                          _buildMoviePlayerSession(
                            feature: feature,
                            featuredFilm: featuredFilm,
                            runtime: runtime,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                Expanded(
                  child: _MediaActionSurface(
                    key: const Key('movie-watchlist-toggle'),
                    label:
                        watchlisted ? 'In watchlist' : feature.secondaryAction,
                    selected: false,
                    onTap: () => onToggleWatchlist(contentKey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaDetailLine {
  const _MediaDetailLine({required this.label, required this.value});

  final String label;
  final String value;
}

class _MediaActionSurface extends StatelessWidget {
  const _MediaActionSurface({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ShellControlButton(
      label: label,
      onPressed: onTap,
      controlRole: ShellControlRole.action,
      presentation: ShellControlPresentation.textOnly,
      emphasis: selected,
    );
  }
}

class _MediaDetailRow extends StatelessWidget {
  const _MediaDetailRow({required this.line});

  final _MediaDetailLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 144,
          child: Text(
            line.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CrispyOverhaulTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: CrispyOverhaulTokens.small),
        Expanded(
          child: Text(
            line.value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

String _shelfTitle(bool movies, MediaScope scope) {
  final String noun = movies ? 'Films' : 'Series';
  switch (scope) {
    case MediaScope.featured:
      return 'Featured $noun';
    case MediaScope.trending:
      return 'Trending $noun';
    case MediaScope.recent:
      return 'Recently Added $noun';
    case MediaScope.library:
      return 'Library $noun';
  }
}

PlayerSession _buildMoviePlayerSession({
  required HeroFeature feature,
  required ShelfItem featuredFilm,
  required MediaRuntimeSnapshot runtime,
}) {
  final MediaRuntimeItemSnapshot? playbackItem = _findMoviePlaybackItem(
    runtime,
    featuredFilm.title,
  );
  return PlayerSession(
    kind: PlayerContentKind.movie,
    originLabel: 'Media · Movies',
    queueLabel: 'Up next',
    queue: <PlayerQueueItem>[
      PlayerQueueItem(
        eyebrow: 'Featured film',
        title: featuredFilm.title,
        subtitle: featuredFilm.caption,
        summary: feature.summary,
        progressLabel: '01:24 / 02:11 · Resume from your last position',
        progressValue: 0.64,
        badges: const <String>['4K', 'Dolby Audio', 'Resume'],
        detailLines: <String>[
          feature.title,
          'Feature playback keeps shell chrome out of the way.',
          'Back collapses player surfaces before returning to Media.',
        ],
        artwork: featuredFilm.artwork ?? feature.artwork,
        playbackSource: playbackItem?.playbackSource,
        playbackStream: playbackItem?.playbackStream,
      ),
    ],
    activeIndex: 0,
    primaryActionLabel: 'Resume',
    secondaryActionLabel: 'Restart',
    playbackUri: playbackItem?.playbackStream?.uri,
    chooserGroups: chooserGroupsForQueueItem(
      PlayerQueueItem(
        eyebrow: 'Featured film',
        title: featuredFilm.title,
        subtitle: featuredFilm.caption,
        summary: feature.summary,
        progressLabel: '01:24 / 02:11 · Resume from your last position',
        progressValue: 0.64,
        badges: const <String>['4K', 'Dolby Audio', 'Resume'],
        detailLines: <String>[
          feature.title,
          'Feature playback keeps shell chrome out of the way.',
          'Back collapses player surfaces before returning to Media.',
        ],
        artwork: featuredFilm.artwork ?? feature.artwork,
        playbackSource: playbackItem?.playbackSource,
        playbackStream: playbackItem?.playbackStream,
      ),
    ),
    statsLines: const <String>[
      'Resolved stream: direct movie playback',
      'Playback path: internal player',
    ],
  );
}

PlayerSession _buildSeriesPlayerSession({
  required SeriesDetailContent detail,
  required MediaRuntimeSnapshot runtime,
  required int selectedSeasonIndex,
  required int selectedEpisodeIndex,
}) {
  final SeriesSeasonDetail season = detail.seasons[selectedSeasonIndex];
  final MediaRuntimeSeasonSnapshot runtimeSeason =
      runtime.seriesDetail.seasons[selectedSeasonIndex];
  final List<PlayerQueueItem> queue = season.episodes
      .asMap()
      .entries
      .map(
        (MapEntry<int, SeriesEpisodeDetail> entry) => PlayerQueueItem(
          eyebrow: season.label,
          title: entry.value.title,
          subtitle: '${entry.value.code} · ${entry.value.durationLabel}',
          summary: entry.value.summary,
          progressLabel:
              '00:08 / ${entry.value.durationLabel} · Continue episode',
          progressValue: 0.18,
          badges: const <String>['Episode', 'Next-up enabled'],
          detailLines: <String>[
            detail.summaryTitle,
            'Episode switching stays inside player.',
            'Back collapses player overlays before exiting to Series.',
          ],
          playbackSource: runtimeSeason.episodes[entry.key].playbackSource,
          playbackStream: runtimeSeason.episodes[entry.key].playbackStream,
        ),
      )
      .toList(growable: false);
  return PlayerSession(
    kind: PlayerContentKind.episode,
    originLabel: 'Media · Series',
    queueLabel: season.label,
    queue: queue,
    activeIndex: selectedEpisodeIndex,
    primaryActionLabel: 'Resume',
    secondaryActionLabel: 'Next Episode',
    playbackUri: queue[selectedEpisodeIndex].playbackStream?.uri,
    chooserGroups: chooserGroupsForQueueItem(queue[selectedEpisodeIndex]),
    statsLines: const <String>[
      'Autoplay next: queued',
      'Switching path: same-season without exit',
    ],
  );
}

MediaRuntimeItemSnapshot? _findMoviePlaybackItem(
  MediaRuntimeSnapshot runtime,
  String title,
) {
  for (final MediaRuntimeCollectionSnapshot collection
      in runtime.movieCollections) {
    for (final MediaRuntimeItemSnapshot item in collection.items) {
      if (item.title == title) {
        return item;
      }
    }
  }
  return null;
}
