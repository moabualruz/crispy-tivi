import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:flutter/material.dart';

class ShellTopBar extends StatelessWidget {
  const ShellTopBar({
    required this.activeRoute,
    required this.onSelectRoute,
    required this.onOpenSettings,
    super.key,
  });

  final ShellRoute activeRoute;
  final ValueChanged<ShellRoute> onSelectRoute;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    const double navRadius = CrispyOverhaulTokens.radiusControl;
    const double navInset = 4;
    return Row(
      children: <Widget>[
        Text(
          'CRISPYTIVI',
          style: textTheme.titleMedium?.copyWith(
            letterSpacing: 1.8,
            color: CrispyOverhaulTokens.textSecondary,
          ),
        ),
        const SizedBox(width: CrispyOverhaulTokens.section),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: CrispyShellRoles.navGroupDecoration(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: navInset,
                  vertical: navInset,
                ),
                child: Wrap(
                  spacing: navInset,
                  runSpacing: navInset,
                  children: mainNavigationRoutes
                      .map(
                        (ShellRoute route) => _RouteButton(
                          route: route,
                          selected: route == activeRoute,
                          onPressed: () => onSelectRoute(route),
                          radius: navRadius - navInset,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ),
        _UtilityButton(
          selected: activeRoute == ShellRoute.settings,
          icon: Icons.settings_outlined,
          label: 'Settings',
          onPressed: onOpenSettings,
        ),
        const SizedBox(width: CrispyOverhaulTokens.small),
        const _ProfileTile(),
        const SizedBox(width: CrispyOverhaulTokens.medium),
        Text(
          '15:37',
          style: textTheme.titleMedium?.copyWith(
            color: CrispyOverhaulTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RouteButton extends StatelessWidget {
  const _RouteButton({
    required this.route,
    required this.selected,
    required this.onPressed,
    required this.radius,
  });

  final ShellRoute route;
  final bool selected;
  final VoidCallback onPressed;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: CrispyShellRoles.navButtonStyle(
        selected: selected,
        radius: radius,
      ),
      child: Text(
        route.label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: CrispyShellRoles.utilityButtonStyle(selected: selected),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: CrispyShellRoles.profileTileDecoration(),
      alignment: Alignment.center,
      child: const Text(
        'P',
        style: TextStyle(
          color: CrispyOverhaulTokens.profileText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
