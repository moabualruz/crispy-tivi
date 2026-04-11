import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/mock_shell/data/mock_shell_catalog.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/feature_hero.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/section_shelf.dart';
import 'package:flutter/material.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const <Widget>[
        FeatureHero(feature: homeHero),
        SizedBox(height: CrispyOverhaulTokens.section),
        SectionShelf(title: 'Continue Watching', items: continueWatchingItems),
        SizedBox(height: CrispyOverhaulTokens.section),
        SectionShelf(title: 'Live Now', items: liveNowItems),
        SizedBox(height: CrispyOverhaulTokens.section),
        SectionShelf(title: 'Quick Access', items: quickAccessItems),
      ],
    );
  }
}
