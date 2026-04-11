import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:flutter/material.dart';

final class CrispyShellRoles {
  const CrispyShellRoles._();

  static const double navGroupInset = 4;

  static const LinearGradient backdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      CrispyOverhaulTokens.shellBackdropTop,
      CrispyOverhaulTokens.surfaceVoid,
    ],
  );

  static const RadialGradient ambientHighlight = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.1,
    colors: <Color>[CrispyOverhaulTokens.shellAmbientLight, Color(0x00000000)],
  );

  static const RadialGradient ambientPrimary = RadialGradient(
    colors: <Color>[
      CrispyOverhaulTokens.shellAmbientPrimary,
      Color(0x008DA4C7),
    ],
  );

  static const RadialGradient ambientSecondary = RadialGradient(
    colors: <Color>[
      CrispyOverhaulTokens.shellAmbientSecondary,
      Color(0x00DCE2EA),
    ],
  );

  static BoxDecoration shellStageDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceVoid,
    border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
  );

  static BoxDecoration panelDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfacePanel,
    border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
  );

  static BoxDecoration insetPanelDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceInset,
    border: Border.all(color: CrispyOverhaulTokens.borderStrong),
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
  );

  static BoxDecoration infoPlateDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceHighlight,
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
  );

  static BoxDecoration navGroupDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceGlass,
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
    border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 4)),
    ],
  );

  static ButtonStyle selectorButtonStyle({required bool selected}) {
    return TextButton.styleFrom(
      foregroundColor:
          selected
              ? CrispyOverhaulTokens.navSelectedText
              : CrispyOverhaulTokens.textSecondary,
      backgroundColor:
          selected
              ? CrispyOverhaulTokens.navSelectedBackground
              : CrispyOverhaulTokens.surfaceInset,
      padding: const EdgeInsets.symmetric(
        horizontal: CrispyOverhaulTokens.medium,
        vertical: CrispyOverhaulTokens.small,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
        side: BorderSide(
          color:
              selected
                  ? CrispyOverhaulTokens.navSelectedBorder
                  : CrispyOverhaulTokens.borderSubtle,
        ),
      ),
      overlayColor: CrispyOverhaulTokens.navOverlay,
    );
  }

  static ButtonStyle navButtonStyle({
    required bool selected,
    required double radius,
  }) {
    return TextButton.styleFrom(
      foregroundColor:
          selected
              ? CrispyOverhaulTokens.navSelectedText
              : CrispyOverhaulTokens.textPrimary,
      backgroundColor:
          selected
              ? CrispyOverhaulTokens.navSelectedBackground
              : Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: CrispyOverhaulTokens.medium,
        vertical: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color:
              selected
                  ? CrispyOverhaulTokens.navSelectedBorder
                  : Colors.transparent,
        ),
      ),
      overlayColor: CrispyOverhaulTokens.navOverlay,
      elevation: 0,
    );
  }

  static ButtonStyle utilityButtonStyle({required bool selected}) {
    return TextButton.styleFrom(
      foregroundColor: CrispyOverhaulTokens.textPrimary,
      backgroundColor:
          selected
              ? CrispyOverhaulTokens.utilitySelectedBackground
              : CrispyOverhaulTokens.utilityBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: CrispyOverhaulTokens.small,
        vertical: CrispyOverhaulTokens.small,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
        side: BorderSide(
          color:
              selected
                  ? CrispyOverhaulTokens.accentFocus
                  : CrispyOverhaulTokens.borderStrong,
        ),
      ),
    );
  }

  static BoxDecoration profileTileDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.profileBackground,
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
    border: Border.all(color: CrispyOverhaulTokens.profileBorder),
  );

  static BoxDecoration searchFieldDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceHighlight,
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
    border: Border.all(color: CrispyOverhaulTokens.accentFocus),
  );
}
