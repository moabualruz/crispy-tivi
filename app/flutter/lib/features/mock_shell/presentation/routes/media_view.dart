import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_content.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/feature_hero.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/section_selector.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/section_shelf.dart';
import 'package:flutter/material.dart';

class MediaView extends StatelessWidget {
  const MediaView({
    required this.content,
    required this.availableScopes,
    required this.panel,
    required this.scope,
    required this.onSelectScope,
    super.key,
  });

  final MockShellContentSnapshot content;
  final List<MediaScope> availableScopes;
  final MediaPanel panel;
  final MediaScope scope;
  final ValueChanged<MediaScope> onSelectScope;

  @override
  Widget build(BuildContext context) {
    final bool movies = panel == MediaPanel.movies;
    return ListView(
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
        _MediaLeadRow(content: content, movies: movies),
        const SizedBox(height: CrispyOverhaulTokens.section),
        _MediaFocusCard(content: content, movies: movies),
        const SizedBox(height: CrispyOverhaulTokens.section),
        if (movies) ...<Widget>[
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

  final MockShellContentSnapshot content;
  final bool movies;

  @override
  Widget build(BuildContext context) {
    final HeroFeature feature = movies ? content.movieHero : content.seriesHero;
    final Widget focusCard = _MediaFocusCard(content: content, movies: movies);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: movies ? 7 : 5,
          child: FeatureHero(feature: feature),
        ),
        const SizedBox(width: CrispyOverhaulTokens.large),
        Expanded(
          flex: movies ? 5 : 7,
          child: focusCard,
        ),
      ],
    );
  }
}

class _MediaFocusCard extends StatelessWidget {
  const _MediaFocusCard({required this.content, required this.movies});

  final MockShellContentSnapshot content;
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
                  ),
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                Expanded(
                  child: _MediaActionSurface(
                    label: feature.secondaryAction,
                    selected: false,
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
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
