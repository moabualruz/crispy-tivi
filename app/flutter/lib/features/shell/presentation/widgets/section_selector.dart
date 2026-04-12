import 'package:crispy_tivi/core/theme/crispy_shell_controls.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_controls.dart';
import 'package:flutter/material.dart';

class SectionSelector<T> extends StatelessWidget {
  const SectionSelector({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.keyBuilder,
    required this.onSelect,
    super.key,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final String Function(T value) keyBuilder;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            color: CrispyOverhaulTokens.textSecondary,
          ),
        ),
        const SizedBox(height: CrispyOverhaulTokens.small),
        DecoratedBox(
          decoration: CrispyShellRoles.navGroupDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(CrispyShellRoles.navGroupInset),
            child: Wrap(
              spacing: CrispyShellRoles.navGroupInset,
              runSpacing: CrispyShellRoles.navGroupInset,
              children: values
                  .map(
                    (T value) => _SelectorButton(
                      itemKey: Key(keyBuilder(value)),
                      label: labelBuilder(value),
                      selected: value == selected,
                      onPressed: () => onSelect(value),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectorButton extends StatelessWidget {
  const _SelectorButton({
    required this.itemKey,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Key itemKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShellControlButton(
      controlKey: itemKey,
      label: label,
      onPressed: onPressed,
      controlRole: ShellControlRole.selector,
      presentation: ShellControlPresentation.textOnly,
      selected: selected,
    );
  }
}
