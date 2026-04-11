import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/mock_shell/data/mock_shell_catalog.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/feature_hero.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/section_selector.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/section_shelf.dart';
import 'package:flutter/material.dart';

class MediaView extends StatelessWidget {
  const MediaView({
    required this.panel,
    required this.scope,
    required this.onSelectScope,
    super.key,
  });

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
          title: 'Browse scope',
          values: MediaScope.values,
          selected: scope,
          labelBuilder: (MediaScope value) => value.label,
          keyBuilder: (MediaScope value) => 'media-scope-${value.name}',
          onSelect: onSelectScope,
        ),
        const SizedBox(height: CrispyOverhaulTokens.large),
        FeatureHero(feature: movies ? movieHero : seriesHero),
        const SizedBox(height: CrispyOverhaulTokens.section),
        SectionShelf(
          title: _shelfTitle(movies, scope),
          items: movies ? topFilms : topSeries,
          showRank: true,
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
