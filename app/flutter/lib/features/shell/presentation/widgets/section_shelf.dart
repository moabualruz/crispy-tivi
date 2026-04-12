import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_artwork.dart';
import 'package:flutter/material.dart';

class SectionShelf extends StatelessWidget {
  const SectionShelf({
    required this.title,
    required this.items,
    this.showRank = false,
    super.key,
  });

  final String title;
  final List<ShelfItem> items;
  final bool showRank;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: textTheme.titleLarge),
        const SizedBox(height: CrispyOverhaulTokens.medium),
        SizedBox(
          height: 192,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder:
                (BuildContext context, int index) =>
                    ShelfCard(item: items[index], showRank: showRank),
            separatorBuilder:
                (BuildContext context, int index) =>
                    const SizedBox(width: CrispyOverhaulTokens.medium),
            itemCount: items.length,
          ),
        ),
      ],
    );
  }
}

class ShelfCard extends StatelessWidget {
  const ShelfCard({required this.item, this.showRank = false, super.key});

  final ShelfItem item;
  final bool showRank;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: showRank ? 250 : 220,
      child: DecoratedBox(
        decoration: CrispyShellRoles.shelfCardDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(CrispyOverhaulTokens.small),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ShellArtwork(
                  source: item.artwork,
                  borderRadius: BorderRadius.circular(
                    CrispyOverhaulTokens.radiusCard,
                  ),
                  overlay: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ArtworkTitleSafeOverlay(
                        decoration:
                            CrispyShellRoles.shelfArtworkScrimDecoration(),
                      ),
                      Positioned(
                        left: CrispyOverhaulTokens.small,
                        right: CrispyOverhaulTokens.small,
                        bottom: CrispyOverhaulTokens.small,
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: CrispyOverhaulTokens.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CrispyOverhaulTokens.small),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (showRank && item.rank != null) ...<Widget>[
                    Text(
                      '${item.rank}',
                      style: textTheme.headlineLarge?.copyWith(
                        color: CrispyOverhaulTokens.textMuted,
                        fontSize: 54,
                      ),
                    ),
                    const SizedBox(width: CrispyOverhaulTokens.small),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(item.title, style: textTheme.titleMedium),
                        const SizedBox(height: CrispyOverhaulTokens.compact),
                        Text(item.caption, style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
