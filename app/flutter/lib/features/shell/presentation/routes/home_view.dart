import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/feature_hero.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/section_shelf.dart';
import 'package:flutter/material.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    required this.quickAccessOrder,
    required this.content,
    super.key,
  });

  final List<String> quickAccessOrder;
  final ShellContentSnapshot content;

  @override
  Widget build(BuildContext context) {
    final List<ShelfItem> quickAccessItems = _orderedQuickAccessItems(
      quickAccessOrder,
    );
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        FeatureHero(feature: content.homeHero),
        const SizedBox(height: CrispyOverhaulTokens.section),
        SectionShelf(
          title: 'Continue Watching',
          items: content.continueWatching,
        ),
        const SizedBox(height: CrispyOverhaulTokens.section),
        SectionShelf(title: 'Live Now', items: content.liveNow),
        const SizedBox(height: CrispyOverhaulTokens.section),
        SectionShelf(title: 'Quick Access', items: quickAccessItems),
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
  ShelfItem(title: 'Search', caption: 'Find channels, movies, settings'),
  ShelfItem(title: 'Settings', caption: 'System and playback controls'),
  ShelfItem(title: 'Series', caption: 'Jump into prestige collections'),
  ShelfItem(title: 'Live TV Guide', caption: 'Jump into the schedule'),
];
