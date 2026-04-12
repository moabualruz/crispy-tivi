import 'package:crispy_tivi/core/theme/crispy_shell_controls.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_icons.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_controls.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_iconography.dart';
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
            Row(
              children: <Widget>[
                ShellIconGraphic(
                  icon: CrispyShellIcons.sidebarTitle(title),
                  role: ShellIconRole.panel,
                ),
                const SizedBox(width: CrispyOverhaulTokens.small),
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: CrispyOverhaulTokens.textSecondary,
                  ),
                ),
              ],
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
                      title: title,
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
    required this.title,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key? itemKey;
  final String title;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ShellControlButton(
      controlKey: itemKey,
      label: label,
      icon: CrispyShellIcons.sidebarItem(title, label),
      onPressed: onTap,
      controlRole: ShellControlRole.selector,
      presentation: ShellControlPresentation.iconAndText,
      contentAlignment: AlignmentDirectional.centerStart,
      expandLabelRow: true,
      selected: selected,
    );
  }
}
