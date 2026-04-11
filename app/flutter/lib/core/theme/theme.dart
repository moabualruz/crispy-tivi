import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:flutter/material.dart';

ThemeData buildCrispyTheme() {
  final ColorScheme scheme = ColorScheme.dark(
    surface: CrispyOverhaulTokens.surfacePanel,
    primary: CrispyOverhaulTokens.textPrimary,
    secondary: CrispyOverhaulTokens.accentActionBlue,
    tertiary: CrispyOverhaulTokens.accentBrand,
    error: CrispyOverhaulTokens.semanticDanger,
  );

  final TextTheme textTheme = Typography.whiteMountainView.copyWith(
    headlineLarge: const TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w600,
      color: CrispyOverhaulTokens.textPrimary,
      height: 1.06,
    ),
    headlineMedium: const TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w600,
      color: CrispyOverhaulTokens.textPrimary,
      height: 1.1,
    ),
    titleLarge: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: CrispyOverhaulTokens.textPrimary,
    ),
    titleMedium: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: CrispyOverhaulTokens.textPrimary,
    ),
    bodyLarge: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: CrispyOverhaulTokens.textPrimary,
      height: 1.35,
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: CrispyOverhaulTokens.textSecondary,
      height: 1.35,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: CrispyOverhaulTokens.surfaceVoid,
    colorScheme: scheme,
    textTheme: textTheme,
    cardTheme: const CardThemeData(
      color: CrispyOverhaulTokens.surfaceRaised,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: CrispyOverhaulTokens.borderSubtle,
      thickness: 1,
      space: 1,
    ),
  );
}
