import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:flutter/material.dart';

class LocalSidebar extends StatelessWidget {
  const LocalSidebar({
    required this.title,
    required this.items,
    required this.selectedIndex,
    required this.onSelectIndex,
    this.itemKeyPrefix,
    super.key,
  });

  final String title;
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;
  final String? itemKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: CrispyShellRoles.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                color: CrispyOverhaulTokens.textSecondary,
              ),
            ),
            const SizedBox(height: CrispyOverhaulTokens.large),
            Expanded(
              child: ListView.separated(
                itemBuilder:
                    (BuildContext context, int index) => _SidebarItem(
                      itemKey:
                          itemKeyPrefix == null
                              ? null
                              : Key('${itemKeyPrefix!}-${items[index]}'),
                      label: items[index],
                      selected: index == selectedIndex,
                      onTap: () => onSelectIndex(index),
                    ),
                separatorBuilder:
                    (BuildContext context, int index) =>
                        const SizedBox(height: CrispyOverhaulTokens.small),
                itemCount: items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.itemKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key? itemKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: itemKey,
      onPressed: onTap,
      style: CrispyShellRoles.selectorButtonStyle(selected: selected).copyWith(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: CrispyOverhaulTokens.medium,
            vertical: CrispyOverhaulTokens.medium,
          ),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color:
                selected
                    ? CrispyOverhaulTokens.navSelectedText
                    : CrispyOverhaulTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
