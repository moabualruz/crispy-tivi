import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_content.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/shell_artwork.dart';
import 'package:flutter/material.dart';

class SearchView extends StatelessWidget {
  const SearchView({required this.content, super.key});

  final MockShellContentSnapshot content;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        DecoratedBox(
          decoration: CrispyShellRoles.panelDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Search', style: textTheme.headlineLarge),
                      const SizedBox(height: CrispyOverhaulTokens.medium),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Text(
                          'Search live channels, films, and series from the active content catalog. '
                          'Settings stays in Settings.',
                          style: textTheme.bodyLarge?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: CrispyOverhaulTokens.large),
                      const _SearchFieldPlate(),
                      const SizedBox(height: CrispyOverhaulTokens.small),
                      Text(
                        'Global content scope. The handoff should feel like an entry into live and media results, not a settings hub.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: CrispyOverhaulTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CrispyOverhaulTokens.section),
                SizedBox(
                  width: 320,
                  child: DecoratedBox(
                    decoration: CrispyShellRoles.infoPlateDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Search handoff',
                            style: textTheme.titleMedium?.copyWith(
                              color: CrispyOverhaulTokens.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: CrispyOverhaulTokens.small),
                          Text(
                            'Browse live content, films, and series with the same shell language used elsewhere in the app.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: CrispyOverhaulTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.section),
        for (final SearchResultGroup group in content.searchGroups) ...<Widget>[
          _SearchGroup(group: group),
          const SizedBox(height: CrispyOverhaulTokens.section),
        ],
      ],
    );
  }
}

class _SearchFieldPlate extends StatelessWidget {
  const _SearchFieldPlate();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.searchFieldDecoration(),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: CrispyOverhaulTokens.large,
          vertical: CrispyOverhaulTokens.medium,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.search, color: CrispyOverhaulTokens.textSecondary),
            SizedBox(width: CrispyOverhaulTokens.small),
            Expanded(
              child: Text(
                'Search live and media titles',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: CrispyOverhaulTokens.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchGroup extends StatelessWidget {
  const _SearchGroup({required this.group});

  final SearchResultGroup group;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(group.title, style: textTheme.titleLarge),
            const SizedBox(width: CrispyOverhaulTokens.small),
            Text(
              '${group.results.length} result${group.results.length == 1 ? '' : 's'}',
              style: textTheme.bodyMedium?.copyWith(
                color: CrispyOverhaulTokens.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: CrispyOverhaulTokens.medium),
        DecoratedBox(
          decoration: CrispyShellRoles.searchResultDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
            child: Wrap(
              spacing: CrispyOverhaulTokens.medium,
              runSpacing: CrispyOverhaulTokens.medium,
              children: <Widget>[
                for (final ShelfItem item in group.results)
                  _SearchResultCard(item: item),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.item});

  final ShelfItem item;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 240,
      child: DecoratedBox(
        decoration: CrispyShellRoles.shelfCardDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(CrispyOverhaulTokens.small),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 1.55,
                child: ShellArtwork(
                  source: item.artwork,
                  borderRadius: BorderRadius.circular(
                    CrispyOverhaulTokens.radiusCard,
                  ),
                ),
              ),
              const SizedBox(height: CrispyOverhaulTokens.small),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: CrispyOverhaulTokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: CrispyOverhaulTokens.compact),
              Text(
                item.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: CrispyOverhaulTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
