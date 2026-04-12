import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/feature_hero.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/section_selector.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/section_shelf.dart';
import 'package:flutter/material.dart';

class MediaView extends StatelessWidget {
  const MediaView({
    required this.content,
    required this.availableScopes,
    required this.panel,
    required this.scope,
    required this.onSelectScope,
    required this.seriesSeasonIndex,
    required this.seriesEpisodeIndex,
    required this.launchedSeriesEpisodeIndex,
    required this.onSelectSeriesSeasonIndex,
    required this.onSelectSeriesEpisodeIndex,
    required this.onLaunchSeriesEpisode,
    super.key,
  });

  final ShellContentSnapshot content;
  final List<MediaScope> availableScopes;
  final MediaPanel panel;
  final MediaScope scope;
  final ValueChanged<MediaScope> onSelectScope;
  final int seriesSeasonIndex;
  final int seriesEpisodeIndex;
  final int? launchedSeriesEpisodeIndex;
  final ValueChanged<int> onSelectSeriesSeasonIndex;
  final ValueChanged<int> onSelectSeriesEpisodeIndex;
  final VoidCallback onLaunchSeriesEpisode;

  @override
  Widget build(BuildContext context) {
    final bool movies = panel == MediaPanel.movies;
    return ListView(
      key: const Key('media-list-view'),
      padding: EdgeInsets.zero,
      children: <Widget>[
        SectionSelector<MediaScope>(
          title: movies ? 'Film scope' : 'Series scope',
          values: availableScopes,
          selected: scope,
          labelBuilder: (MediaScope value) => value.label,
          keyBuilder: (MediaScope value) => 'media-scope-${value.name}',
          onSelect: onSelectScope,
        ),
        const SizedBox(height: CrispyOverhaulTokens.small),
        if (movies) ...<Widget>[
          _MediaLeadRow(content: content, movies: movies),
          const SizedBox(height: CrispyOverhaulTokens.section),
          _MovieDetailCard(
            key: const Key('movie-detail-card'),
            feature: content.movieHero,
            featuredFilm: content.topFilms.first,
          ),
          const SizedBox(height: CrispyOverhaulTokens.section),
          SectionShelf(
            title: _shelfTitle(movies, scope),
            items: content.topFilms,
            showRank: true,
          ),
          const SizedBox(height: CrispyOverhaulTokens.section),
          SectionShelf(
            title: 'Continue Watching Films',
            items: content.continueWatching,
          ),
        ] else ...<Widget>[
          _SeriesDetailPanel(
            key: const Key('series-detail-panel'),
            detail: content.seriesDetail,
            selectedSeasonIndex: seriesSeasonIndex,
            selectedEpisodeIndex: seriesEpisodeIndex,
            launchedEpisodeIndex: launchedSeriesEpisodeIndex,
            onSelectSeasonIndex: onSelectSeriesSeasonIndex,
            onSelectEpisodeIndex: onSelectSeriesEpisodeIndex,
            onLaunchEpisode: onLaunchSeriesEpisode,
          ),
          const SizedBox(height: CrispyOverhaulTokens.section),
          _MediaLeadRow(content: content, movies: movies),
          const SizedBox(height: CrispyOverhaulTokens.section),
          _MediaFocusCard(content: content, movies: movies),
          const SizedBox(height: CrispyOverhaulTokens.section),
          SectionShelf(
            title: 'Next Up Series',
            items: content.continueWatching,
          ),
          const SizedBox(height: CrispyOverhaulTokens.section),
          SectionShelf(
            title: _shelfTitle(movies, scope),
            items: content.topSeries,
            showRank: true,
          ),
        ],
      ],
    );
  }
}

class _MediaLeadRow extends StatelessWidget {
  const _MediaLeadRow({required this.content, required this.movies});

  final ShellContentSnapshot content;
  final bool movies;

  @override
  Widget build(BuildContext context) {
    final HeroFeature feature = movies ? content.movieHero : content.seriesHero;
    final Widget focusCard = _MediaFocusCard(content: content, movies: movies);
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
  const _MediaFocusCard({required this.content, required this.movies});

  final ShellContentSnapshot content;
  final bool movies;

  @override
  Widget build(BuildContext context) {
    final HeroFeature feature = movies ? content.movieHero : content.seriesHero;
    final List<_MediaDetailLine> lines =
        movies
            ? <_MediaDetailLine>[
              const _MediaDetailLine(
                label: 'Primary emphasis',
                value: 'Poster-led feature browsing',
              ),
              const _MediaDetailLine(
                label: 'Continuation',
                value: 'Resume films from the top shelf',
              ),
              const _MediaDetailLine(
                label: 'Route behavior',
                value: 'Featured films lead, scope narrows second',
              ),
            ]
            : <_MediaDetailLine>[
              const _MediaDetailLine(
                label: 'Primary emphasis',
                value: 'Episode continuity and season flow',
              ),
              const _MediaDetailLine(
                label: 'Continuation',
                value: 'Next up stays visible above the shelf',
              ),
              const _MediaDetailLine(
                label: 'Route behavior',
                value: 'Series context leads, featured series follow',
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
              movies
                  ? 'Feature-first movie browsing'
                  : 'Episode-first series browsing',
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
    required this.selectedSeasonIndex,
    required this.selectedEpisodeIndex,
    required this.launchedEpisodeIndex,
    required this.onSelectSeasonIndex,
    required this.onSelectEpisodeIndex,
    required this.onLaunchEpisode,
  });

  final SeriesDetailContent detail;
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
                  ? 'Launched ${selectedEpisode.code} into the mock player handoff.'
                  : 'Ready to launch ${selectedEpisode.code} into the mock player handoff.',
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
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('series-launch-action'),
                onPressed: onLaunchEpisode,
                style: CrispyShellRoles.actionButtonStyle(emphasis: true),
                child: Text(
                  launchReady ? 'Launched' : selectedEpisode.handoffLabel,
                ),
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
    return TextButton(
      key: itemKey,
      onPressed: onPressed,
      style: CrispyShellRoles.selectorButtonStyle(selected: selected),
      child: Text(
        '${episode.code} ${episode.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MovieDetailCard extends StatelessWidget {
  const _MovieDetailCard({
    required this.feature,
    required this.featuredFilm,
    super.key,
  });

  final HeroFeature feature;
  final ShelfItem featuredFilm;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
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
              'Featured film browsing with explicit player handoff.',
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
                label: 'Featured film',
                value: 'The selection lives on the top film shelf.',
              ),
            ),
            _MediaDetailRow(
              line: _MediaDetailLine(
                label: 'Shelf pick',
                value: '${featuredFilm.title} · ${featuredFilm.caption}',
              ),
            ),
            const _MediaDetailRow(
              line: _MediaDetailLine(
                label: 'Playback',
                value: 'Launch mock player from detail, not from the shelf.',
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MediaActionSurface(
                    key: const Key('movie-player-launch'),
                    label: 'Launch mock player',
                    selected: true,
                    onTap:
                        () => _showMoviePlayerPreview(
                          context,
                          feature: feature,
                          film: featuredFilm,
                        ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
        child: Ink(
          decoration:
              selected
                  ? CrispyShellRoles.iconPlateDecoration()
                  : CrispyShellRoles.panelDecoration(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispyOverhaulTokens.medium,
              vertical: CrispyOverhaulTokens.small,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    selected
                        ? CrispyOverhaulTokens.navSelectedText
                        : CrispyOverhaulTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showMoviePlayerPreview(
  BuildContext context, {
  required HeroFeature feature,
  required ShelfItem film,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final TextTheme textTheme = Theme.of(dialogContext).textTheme;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: DecoratedBox(
          decoration: CrispyShellRoles.panelDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Mock movie player', style: textTheme.titleLarge),
                  const SizedBox(height: CrispyOverhaulTokens.compact),
                  Text(
                    feature.title,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  Text(
                    '${film.title} is ready to play from the movie detail handoff.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: CrispyOverhaulTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.large),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: CrispyShellRoles.actionButtonStyle(
                        emphasis: false,
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
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
