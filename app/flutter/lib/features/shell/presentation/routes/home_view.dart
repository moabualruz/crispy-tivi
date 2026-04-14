import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/feature_hero.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/section_shelf.dart';
import 'package:flutter/material.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    required this.quickAccessOrder,
    required this.hero,
    required this.liveNow,
    required this.continueWatching,
    required this.hasConfiguredProviders,
    super.key,
  });

  final List<String> quickAccessOrder;
  final HeroFeature? hero;
  final List<ShelfItem> liveNow;
  final List<ShelfItem> continueWatching;
  final bool hasConfiguredProviders;

  @override
  Widget build(BuildContext context) {
    if (hero == null && continueWatching.isEmpty && liveNow.isEmpty) {
      return _HomeEmptyState(hasConfiguredProviders: hasConfiguredProviders);
    }
    final List<ShelfItem> quickAccessItems = _orderedQuickAccessItems(
      quickAccessOrder,
    );
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        if (hero != null) FeatureHero(feature: hero!),
        const SizedBox(height: CrispyOverhaulTokens.section),
        SectionShelf(title: 'Continue Watching', items: continueWatching),
        const SizedBox(height: CrispyOverhaulTokens.section),
        SectionShelf(title: 'Live Now', items: liveNow),
        const SizedBox(height: CrispyOverhaulTokens.section),
        SectionShelf(title: 'Quick Access', items: quickAccessItems),
      ],
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({required this.hasConfiguredProviders});

  final bool hasConfiguredProviders;

  @override
  Widget build(BuildContext context) {
    final String title =
        hasConfiguredProviders
            ? 'Import content to unlock Home'
            : 'Finish source setup first';
    final String summary =
        hasConfiguredProviders
            ? 'Home stays empty until configured providers finish importing live or media content.'
            : 'Home stays empty until at least one real source is configured and imported.';
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        DecoratedBox(
          decoration: const BoxDecoration(
            color: CrispyOverhaulTokens.surfacePanel,
            borderRadius: BorderRadius.all(
              Radius.circular(CrispyOverhaulTokens.radiusSheet),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(CrispyOverhaulTokens.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: CrispyOverhaulTokens.small),
                Text(
                  summary,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: CrispyOverhaulTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

List<ShelfItem> _orderedQuickAccessItems(List<String> quickAccessOrder) {
  final Map<String, ShelfItem> itemsByTitle = <String, ShelfItem>{
    for (final ShelfItem item in _quickAccessItems) item.title: item,
  };
  return quickAccessOrder
      .map((String title) => itemsByTitle[title])
      .whereType<ShelfItem>()
      .toList(growable: false);
}

const List<ShelfItem> _quickAccessItems = <ShelfItem>[
  ShelfItem(title: 'Search', caption: 'Find channels, movies, series'),
  ShelfItem(title: 'Settings', caption: 'System and playback controls'),
  ShelfItem(title: 'Series', caption: 'Jump into prestige collections'),
  ShelfItem(title: 'Live TV Guide', caption: 'Jump into the schedule'),
];
