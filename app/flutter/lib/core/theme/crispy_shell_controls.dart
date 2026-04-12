import 'package:flutter/widgets.dart';

enum ShellControlRole { navigation, utility, action, selector, compact }

enum ShellControlPresentation { iconOnly, iconAndText, textOnly }

final class CrispyShellControls {
  const CrispyShellControls._();

  static double height(ShellControlRole role) {
    return switch (role) {
      ShellControlRole.navigation => 46,
      ShellControlRole.utility => 46,
      ShellControlRole.action => 46,
      ShellControlRole.selector => 46,
      ShellControlRole.compact => 40,
    };
  }

  static double iconOnlyExtent(ShellControlRole role) => height(role);

  static EdgeInsets padding(
    ShellControlRole role,
    ShellControlPresentation presentation,
  ) {
    if (presentation == ShellControlPresentation.iconOnly) {
      return EdgeInsets.zero;
    }
    return switch ((role, presentation)) {
      (ShellControlRole.navigation, ShellControlPresentation.iconAndText) =>
        const EdgeInsets.symmetric(horizontal: 16),
      (ShellControlRole.utility, ShellControlPresentation.iconAndText) =>
        const EdgeInsets.symmetric(horizontal: 14),
      (ShellControlRole.action, ShellControlPresentation.iconAndText) =>
        const EdgeInsets.symmetric(horizontal: 16),
      (ShellControlRole.selector, ShellControlPresentation.iconAndText) =>
        const EdgeInsets.symmetric(horizontal: 14),
      (ShellControlRole.selector, ShellControlPresentation.textOnly) =>
        const EdgeInsets.symmetric(horizontal: 14),
      (ShellControlRole.compact, ShellControlPresentation.iconAndText) =>
        const EdgeInsets.symmetric(horizontal: 12),
      (ShellControlRole.compact, ShellControlPresentation.textOnly) =>
        const EdgeInsets.symmetric(horizontal: 12),
      _ => const EdgeInsets.symmetric(horizontal: 16),
    };
  }

  static double iconGap(ShellControlRole role) {
    return switch (role) {
      ShellControlRole.navigation => 12,
      ShellControlRole.utility => 10,
      ShellControlRole.action => 10,
      ShellControlRole.selector => 10,
      ShellControlRole.compact => 8,
    };
  }

  static AlignmentGeometry contentAlignment(
    ShellControlRole role,
    ShellControlPresentation presentation,
  ) {
    if (presentation == ShellControlPresentation.iconOnly) {
      return Alignment.center;
    }
    return Alignment.center;
  }
}
