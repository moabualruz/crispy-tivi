import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_icons.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:flutter/material.dart';

class ShellIconGraphic extends StatelessWidget {
  const ShellIconGraphic({
    required this.icon,
    required this.role,
    this.color = CrispyOverhaulTokens.textSecondary,
    super.key,
  });

  final IconData icon;
  final ShellIconRole role;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: CrispyShellIcons.size(role), color: color);
  }
}

class ShellIconPlate extends StatelessWidget {
  const ShellIconPlate({
    required this.icon,
    required this.role,
    this.color = CrispyOverhaulTokens.textSecondary,
    this.decoration,
    super.key,
  });

  final IconData icon;
  final ShellIconRole role;
  final Color color;
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    final double extent = CrispyShellIcons.plateExtent(role);
    return Container(
      width: extent,
      height: extent,
      decoration: decoration ?? CrispyShellRoles.iconPlateDecoration(),
      alignment: Alignment.center,
      child: ShellIconGraphic(icon: icon, role: role, color: color),
    );
  }
}

class ShellIconLabel extends StatelessWidget {
  const ShellIconLabel({
    required this.icon,
    required this.label,
    required this.role,
    this.color = CrispyOverhaulTokens.textSecondary,
    this.textStyle,
    this.usePlate = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final ShellIconRole role;
  final Color color;
  final TextStyle? textStyle;
  final bool usePlate;

  @override
  Widget build(BuildContext context) {
    final TextStyle resolvedTextStyle =
        textStyle ??
        Theme.of(
          context,
        ).textTheme.bodyLarge!.copyWith(color: color, height: 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (usePlate)
          ShellIconPlate(icon: icon, role: role, color: color)
        else
          ShellIconGraphic(icon: icon, role: role, color: color),
        SizedBox(
          width:
              role == ShellIconRole.badge
                  ? CrispyShellIcons.compactGap
                  : CrispyShellIcons.inlineGap,
        ),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolvedTextStyle,
          ),
        ),
      ],
    );
  }
}
