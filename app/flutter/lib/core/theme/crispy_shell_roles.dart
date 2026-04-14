import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_controls.dart';
import 'package:flutter/material.dart';

final class CrispyShellRoles {
  const CrispyShellRoles._();

  static const double navGroupInset = 4;
  static const double shellViewportWidth = 1440;
  static const double shellViewportHeight = 810;
  static const double shellOuterPadding = 18;
  static const double shellTopBarGap = 16;
  static const double shellSidebarGap = 12;
  static const double shellSidebarWidth = 276;

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

  static BoxDecoration heroSurfaceDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfacePanel,
    border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
  );

  static BoxDecoration heroArtworkFrameDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceHighlight,
    border: Border.all(color: CrispyOverhaulTokens.borderStrong),
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
  );

  static BoxDecoration heroArtworkScrimDecoration() => BoxDecoration(
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
    gradient: const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[Color(0xB30E0E10), Color(0x6618191D), Color(0x2618191D)],
    ),
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

  static BoxDecoration previewStageDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceHighlight,
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
    border: Border.all(color: CrispyOverhaulTokens.borderStrong),
  );

  static BoxDecoration infoPlateDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceHighlight,
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
  );

  static BoxDecoration iconPlateDecoration() => BoxDecoration(
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
      minimumSize: Size(
        0,
        CrispyShellControls.height(ShellControlRole.selector),
      ),
      padding: CrispyShellControls.padding(
        ShellControlRole.selector,
        ShellControlPresentation.textOnly,
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
      minimumSize: Size(
        0,
        CrispyShellControls.height(ShellControlRole.navigation),
      ),
      padding: CrispyShellControls.padding(
        ShellControlRole.navigation,
        ShellControlPresentation.iconAndText,
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
      minimumSize: Size(
        0,
        CrispyShellControls.height(ShellControlRole.utility),
      ),
      padding: CrispyShellControls.padding(
        ShellControlRole.utility,
        ShellControlPresentation.iconAndText,
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

  static ButtonStyle actionButtonStyle({required bool emphasis}) {
    return TextButton.styleFrom(
      foregroundColor: CrispyOverhaulTokens.textPrimary,
      backgroundColor:
          emphasis
              ? CrispyOverhaulTokens.surfaceRaised
              : CrispyOverhaulTokens.surfacePanel,
      minimumSize: Size(0, CrispyShellControls.height(ShellControlRole.action)),
      padding: CrispyShellControls.padding(
        ShellControlRole.action,
        ShellControlPresentation.iconAndText,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
        side: BorderSide(
          color:
              emphasis
                  ? CrispyOverhaulTokens.accentFocus
                  : CrispyOverhaulTokens.borderStrong,
        ),
      ),
      overlayColor: CrispyOverhaulTokens.navOverlay,
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

  static BoxDecoration inputFieldDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceHighlight,
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
    border: Border.all(color: CrispyOverhaulTokens.borderStrong),
  );

  static BoxDecoration shelfCardDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceRaised,
    border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusCard),
  );

  static BoxDecoration denseCardDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceRaised,
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusCard),
    border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
  );

  static BoxDecoration searchResultDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfaceInset,
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusCard),
    border: Border.all(color: CrispyOverhaulTokens.borderStrong),
  );

  static BoxDecoration playerTransportDecoration() => BoxDecoration(
    color: const Color(0xCC18191D),
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
    border: Border.all(color: CrispyOverhaulTokens.borderStrong),
  );

  static BoxDecoration playerInfoDecoration() => BoxDecoration(
    color: const Color(0xCC121316),
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
    border: Border.all(color: CrispyOverhaulTokens.borderStrong),
  );

  static BoxDecoration playerChooserDecoration() => BoxDecoration(
    color: CrispyOverhaulTokens.surfacePanel,
    borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
    border: Border.all(color: CrispyOverhaulTokens.borderStrong),
  );

  static BoxDecoration playerOverlayScrimDecoration() => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0x40000000), Color(0x660A0A0C), Color(0xCC0A0A0C)],
    ),
  );

  static BoxDecoration artworkFallbackDecoration() =>
      const BoxDecoration(color: CrispyOverhaulTokens.surfaceHighlight);

  static BoxDecoration shelfArtworkScrimDecoration() => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0x00000000), Color(0x6618191D)],
    ),
  );
}
