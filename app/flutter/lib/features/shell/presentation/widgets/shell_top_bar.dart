import 'package:crispy_tivi/core/theme/crispy_shell_controls.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_icons.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_controls.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_iconography.dart';
import 'package:flutter/material.dart';

class ShellTopBar extends StatelessWidget {
  const ShellTopBar({
    required this.navigationRoutes,
    required this.activeRoute,
    required this.onSelectRoute,
    required this.onOpenSettings,
    super.key,
  });

  final List<ShellRoute> navigationRoutes;
  final ShellRoute activeRoute;
  final ValueChanged<ShellRoute> onSelectRoute;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    const double navRadius = CrispyOverhaulTokens.radiusControl;
    const double navInset = 4;
    final List<ShellRoute> primaryRoutes = navigationRoutes
        .where((ShellRoute route) => route != ShellRoute.search)
        .toList(growable: false);
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Text(
                'CRISPYTIVI',
                style: textTheme.titleMedium?.copyWith(
                  letterSpacing: 1.8,
                  color: CrispyOverhaulTokens.textSecondary,
                ),
              ),
              const SizedBox(width: CrispyOverhaulTokens.section),
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
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
                        alignment: WrapAlignment.start,
                        children: primaryRoutes
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
            ],
          ),
        ),
        const SizedBox(width: CrispyOverhaulTokens.medium),
        _RouteButton(
          route: ShellRoute.search,
          selected: activeRoute == ShellRoute.search,
          onPressed: () => onSelectRoute(ShellRoute.search),
          radius: navRadius - navInset,
        ),
        const SizedBox(width: CrispyOverhaulTokens.small),
        _UtilityButton(
          selected: activeRoute == ShellRoute.settings,
          icon: CrispyShellIcons.route(ShellRoute.settings),
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
    final bool iconOnly = route == ShellRoute.search;
    return ShellControlButton(
      controlKey: Key('shell-route-${route.name}'),
      label: CrispyShellIcons.routeLabel(route),
      semanticsLabel: route.label,
      icon: CrispyShellIcons.route(route),
      onPressed: onPressed,
      controlRole: ShellControlRole.navigation,
      presentation:
          iconOnly
              ? ShellControlPresentation.iconOnly
              : ShellControlPresentation.iconAndText,
      selected: selected,
      radius: radius,
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
    return ShellControlButton(
      controlKey: const Key('shell-utility-settings'),
      label: label,
      semanticsLabel: label,
      icon: icon,
      onPressed: onPressed,
      controlRole: ShellControlRole.utility,
      presentation: ShellControlPresentation.iconOnly,
      selected: selected,
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CrispyShellControls.height(ShellControlRole.utility),
      height: CrispyShellControls.height(ShellControlRole.utility),
      decoration: CrispyShellRoles.profileTileDecoration(),
      alignment: Alignment.center,
      child: const ShellIconGraphic(
        icon: Icons.person_outline,
        color: CrispyOverhaulTokens.profileText,
        role: ShellIconRole.utility,
      ),
    );
  }
}
