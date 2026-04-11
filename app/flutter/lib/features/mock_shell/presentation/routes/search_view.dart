import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/mock_shell/data/mock_shell_catalog.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';
import 'package:flutter/material.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        DecoratedBox(
          decoration: CrispyShellRoles.panelDecoration(),
          child: const Padding(
            padding: EdgeInsets.all(CrispyOverhaulTokens.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Search live and media titles',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: CrispyOverhaulTokens.textPrimary,
                  ),
                ),
                SizedBox(height: CrispyOverhaulTokens.medium),
                _SearchFieldPlate(),
              ],
            ),
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.section),
        for (final SearchResultGroup group in searchGroups) ...<Widget>[
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
          horizontal: CrispyOverhaulTokens.medium,
          vertical: CrispyOverhaulTokens.medium,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.search, color: CrispyOverhaulTokens.textSecondary),
            SizedBox(width: CrispyOverhaulTokens.small),
            Text(
              'Try "harbor", "arena", or "shadow"',
              style: TextStyle(color: CrispyOverhaulTokens.textSecondary),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(group.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CrispyOverhaulTokens.medium),
        for (final ShelfItem item in group.results) ...<Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: CrispyOverhaulTokens.surfaceInset,
              borderRadius: BorderRadius.circular(
                CrispyOverhaulTokens.radiusCard,
              ),
              border: Border.all(color: CrispyOverhaulTokens.borderStrong),
            ),
            child: ListTile(
              title: Text(item.title),
              subtitle: Text(item.caption),
              trailing: const Icon(
                Icons.arrow_forward,
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: CrispyOverhaulTokens.small),
        ],
      ],
    );
  }
}
