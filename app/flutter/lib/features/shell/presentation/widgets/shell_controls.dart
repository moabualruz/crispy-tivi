import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_controls.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_icons.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_iconography.dart';
import 'package:flutter/material.dart';

class ShellControlButton extends StatelessWidget {
  const ShellControlButton({
    required this.label,
    required this.onPressed,
    required this.controlRole,
    required this.presentation,
    this.icon,
    this.selected = false,
    this.emphasis = false,
    this.radius,
    this.controlKey,
    this.semanticsLabel,
    this.textStyle,
    this.contentAlignment,
    this.expandLabelRow = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final ShellControlRole controlRole;
  final ShellControlPresentation presentation;
  final IconData? icon;
  final bool selected;
  final bool emphasis;
  final double? radius;
  final Key? controlKey;
  final String? semanticsLabel;
  final TextStyle? textStyle;
  final AlignmentGeometry? contentAlignment;
  final bool expandLabelRow;

  @override
  Widget build(BuildContext context) {
    final TextStyle resolvedTextStyle =
        (textStyle ?? Theme.of(context).textTheme.bodyLarge!).copyWith(
          color: _foregroundColor,
          fontWeight: _fontWeight,
          height: 1.0,
        );
    final Widget child = switch (presentation) {
      ShellControlPresentation.iconOnly => Center(
        child: ShellIconGraphic(
          icon: icon!,
          role: _iconRole,
          color: _foregroundColor,
        ),
      ),
      ShellControlPresentation.iconAndText => Row(
        mainAxisSize: expandLabelRow ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          ShellIconGraphic(
            icon: icon!,
            role: _iconRole,
            color: _foregroundColor,
          ),
          SizedBox(width: CrispyShellControls.iconGap(controlRole)),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolvedTextStyle,
            ),
          ),
        ],
      ),
      ShellControlPresentation.textOnly => Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.start,
        style: resolvedTextStyle,
      ),
    };
    final Widget resolvedChild =
        expandLabelRow || contentAlignment != null
            ? Align(
                alignment:
                    contentAlignment ??
                    CrispyShellControls.contentAlignment(
                      controlRole,
                      presentation,
                    ),
                child: child,
              )
            : child;

    return Semantics(
      label: semanticsLabel ?? label,
      button: true,
      child: SizedBox(
        width:
            presentation == ShellControlPresentation.iconOnly
                ? CrispyShellControls.iconOnlyExtent(controlRole)
                : null,
        height: CrispyShellControls.height(controlRole),
        child: TextButton(
          key: controlKey,
          onPressed: onPressed,
          style: _style(),
          child: resolvedChild,
        ),
      ),
    );
  }

  ButtonStyle _style() {
    return switch (controlRole) {
      ShellControlRole.navigation => CrispyShellRoles.navButtonStyle(
        selected: selected,
        radius: radius ?? CrispyOverhaulTokens.radiusControl,
      ).copyWith(
        alignment:
            contentAlignment ??
            CrispyShellControls.contentAlignment(controlRole, presentation),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          CrispyShellControls.padding(controlRole, presentation),
        ),
      ),
      ShellControlRole.utility => CrispyShellRoles.utilityButtonStyle(
        selected: selected,
      ).copyWith(
        alignment:
            contentAlignment ??
            CrispyShellControls.contentAlignment(controlRole, presentation),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          CrispyShellControls.padding(controlRole, presentation),
        ),
      ),
      ShellControlRole.action => CrispyShellRoles.actionButtonStyle(
        emphasis: emphasis,
      ).copyWith(
        alignment:
            contentAlignment ??
            CrispyShellControls.contentAlignment(controlRole, presentation),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          CrispyShellControls.padding(controlRole, presentation),
        ),
      ),
      ShellControlRole.selector => CrispyShellRoles.selectorButtonStyle(
        selected: selected,
      ).copyWith(
        alignment:
            contentAlignment ??
            CrispyShellControls.contentAlignment(controlRole, presentation),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          CrispyShellControls.padding(controlRole, presentation),
        ),
      ),
      ShellControlRole.compact => CrispyShellRoles.actionButtonStyle(
        emphasis: emphasis,
      ).copyWith(
        minimumSize: WidgetStatePropertyAll<Size>(
          Size(0, CrispyShellControls.height(ShellControlRole.compact)),
        ),
        alignment:
            contentAlignment ??
            CrispyShellControls.contentAlignment(controlRole, presentation),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          CrispyShellControls.padding(controlRole, presentation),
        ),
      ),
    };
  }

  Color get _foregroundColor {
    return switch (controlRole) {
      ShellControlRole.navigation =>
        selected
            ? CrispyOverhaulTokens.navSelectedText
            : CrispyOverhaulTokens.textPrimary,
      ShellControlRole.utility => CrispyOverhaulTokens.textPrimary,
      ShellControlRole.action => CrispyOverhaulTokens.textPrimary,
      ShellControlRole.selector =>
        selected
            ? CrispyOverhaulTokens.navSelectedText
            : CrispyOverhaulTokens.textSecondary,
      ShellControlRole.compact => CrispyOverhaulTokens.textPrimary,
    };
  }

  FontWeight get _fontWeight {
    return switch (controlRole) {
      ShellControlRole.navigation => selected ? FontWeight.w700 : FontWeight.w600,
      ShellControlRole.utility => FontWeight.w600,
      ShellControlRole.action => FontWeight.w600,
      ShellControlRole.selector => selected ? FontWeight.w600 : FontWeight.w500,
      ShellControlRole.compact => FontWeight.w600,
    };
  }

  ShellIconRole get _iconRole {
    return switch (controlRole) {
      ShellControlRole.navigation => ShellIconRole.navigation,
      ShellControlRole.utility => ShellIconRole.utility,
      ShellControlRole.action => ShellIconRole.utility,
      ShellControlRole.selector => ShellIconRole.row,
      ShellControlRole.compact => ShellIconRole.compact,
    };
  }
}

class ShellControlSurface extends StatelessWidget {
  const ShellControlSurface({
    required this.onPressed,
    required this.controlRole,
    required this.child,
    this.selected = false,
    this.emphasis = false,
    this.radius,
    this.controlKey,
    this.semanticsLabel,
    this.minHeight,
    this.padding,
    super.key,
  });

  final VoidCallback onPressed;
  final ShellControlRole controlRole;
  final Widget child;
  final bool selected;
  final bool emphasis;
  final double? radius;
  final Key? controlKey;
  final String? semanticsLabel;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minHeight ?? CrispyShellControls.height(controlRole),
        ),
        child: TextButton(
          key: controlKey,
          onPressed: onPressed,
          style: _style(),
          child: child,
        ),
      ),
    );
  }

  ButtonStyle _style() {
    final EdgeInsetsGeometry resolvedPadding =
        padding ??
        CrispyShellControls.padding(
          controlRole,
          ShellControlPresentation.iconAndText,
        );
    return switch (controlRole) {
      ShellControlRole.navigation => CrispyShellRoles.navButtonStyle(
        selected: selected,
        radius: radius ?? CrispyOverhaulTokens.radiusControl,
      ).copyWith(
        alignment: AlignmentDirectional.centerStart,
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(resolvedPadding),
      ),
      ShellControlRole.utility => CrispyShellRoles.utilityButtonStyle(
        selected: selected,
      ).copyWith(
        alignment: AlignmentDirectional.centerStart,
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(resolvedPadding),
      ),
      ShellControlRole.action => CrispyShellRoles.actionButtonStyle(
        emphasis: emphasis,
      ).copyWith(
        alignment: AlignmentDirectional.centerStart,
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(resolvedPadding),
      ),
      ShellControlRole.selector => CrispyShellRoles.selectorButtonStyle(
        selected: selected,
      ).copyWith(
        alignment: AlignmentDirectional.centerStart,
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(resolvedPadding),
      ),
      ShellControlRole.compact => CrispyShellRoles.actionButtonStyle(
        emphasis: emphasis,
      ).copyWith(
        minimumSize: WidgetStatePropertyAll<Size>(
          Size(0, CrispyShellControls.height(ShellControlRole.compact)),
        ),
        alignment: AlignmentDirectional.centerStart,
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(resolvedPadding),
      ),
    };
  }
}
