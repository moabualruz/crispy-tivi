import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
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
        Wrap(
          spacing: CrispyOverhaulTokens.small,
          runSpacing: CrispyOverhaulTokens.small,
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
    return TextButton(
      key: itemKey,
      onPressed: onPressed,
      style: CrispyShellRoles.selectorButtonStyle(selected: selected),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}
