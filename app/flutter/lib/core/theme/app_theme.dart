import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'main_color_hue.dart';
import 'crispy_colors.dart';
import 'crispy_radius.dart';
import 'theme_provider.dart';

/// Builds Material 3 dark theme from a seed color.
///
/// CrispyTivi is dark-mode only. All colors use semantic naming
/// (`surface`, `onSurface`, `primaryContainer`, etc.) — no hardcoded
/// hex values in feature code.
///
/// Custom semantic colors are available via the [CrispyColors]
/// theme extension:
/// ```dart
/// Theme.of(context).crispyColors.liveRed
/// ```
///
/// Usage:
/// ```dart
/// final config = ref.watch(configServiceProvider).value;
/// final appTheme = AppTheme.fromSeedHex(config.theme.seedColorHex);
/// return MaterialApp(
///   theme: appTheme.theme,
///   darkTheme: appTheme.theme,
///   themeMode: ThemeMode.dark,
/// );
/// ```
class AppTheme {
  AppTheme._(this.theme);

  /// Creates dark theme from a hex seed color.
  factory AppTheme.fromSeedHex(String hexColor) {
    final seed = CrispyColors.parseHex(hexColor);
    return AppTheme._(_buildTheme(seed));
  }

  /// Creates theme from a [ThemeState] configuration.
  ///
  /// This is the preferred way to create themes when using the
  /// [themeProvider] for dynamic theme switching.
  factory AppTheme.fromThemeState(ThemeState themeState) {
    return AppTheme._(_buildThemeFromState(themeState));
  }

  /// The dark theme. CrispyTivi is dark-mode only.
  final ThemeData theme;

  /// Flag to disable Google Fonts in tests to avoid asset/network errors.
  static bool useGoogleFonts = true;

  /// Shared shape constant — all M3 components use sharp corners.
  static const _sharpShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(CrispyRadius.tv)),
  );

  /// V2 page transition theme — Zoom on Android/Windows/Linux,
  /// Cupertino on iOS/macOS.
  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(),
    },
  );

  /// Builds component theme overrides that enforce sharp corners
  /// across ALL Material 3 widgets.
  static _ComponentThemes _sharpComponentThemes(ColorScheme colorScheme) {
    return _ComponentThemes(
      elevatedButton: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: _sharpShape),
      ),
      filledButton: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: _sharpShape),
      ),
      outlinedButton: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: _sharpShape),
      ),
      textButton: TextButtonThemeData(
        style: TextButton.styleFrom(shape: _sharpShape),
      ),
      chip: const ChipThemeData(shape: _sharpShape),
      popupMenu: const PopupMenuThemeData(shape: _sharpShape),
      menu: const MenuThemeData(
        style: MenuStyle(shape: WidgetStatePropertyAll(_sharpShape)),
      ),
      segmentedButton: const SegmentedButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(_sharpShape)),
      ),
      toggleButtons: const ToggleButtonsThemeData(
        borderRadius: BorderRadius.all(Radius.circular(CrispyRadius.tv)),
      ),
      listTile: const ListTileThemeData(shape: _sharpShape),
      fab: const FloatingActionButtonThemeData(shape: _sharpShape),
    );
  }

  /// Builds a theme from [ThemeState] with configurable main hue and accent.
  static ThemeData _buildThemeFromState(ThemeState themeState) {
    final mainHue = themeState.mainHue;
    final primaryColor = themeState.primaryColor;

    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    );

    // Apply main hue surface colors and accent overrides
    final colorScheme = baseColorScheme.copyWith(
      surface: mainHue.surface,
      onSurface: const Color(0xFFFFFFFF),
      surfaceContainer: mainHue.raised,
      surfaceContainerHigh: mainHue.surfaceContainerHigh,
      primary: primaryColor,
      primaryContainer: themeState.primaryContainer,
      onPrimaryContainer: themeState.onPrimaryContainer,
    );

    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme =
        useGoogleFonts
            ? GoogleFonts.interTextTheme(baseTextTheme)
            : baseTextTheme;

    final crispyColors = CrispyColors.dark().copyWith(
      glassTint: mainHue.raised.withValues(alpha: 0.85),
    );

    final ct = _sharpComponentThemes(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: mainHue.scaffold,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: textTheme,
      pageTransitionsTheme: _pageTransitions,
      extensions: <ThemeExtension<dynamic>>[crispyColors],
      // ── App chrome ──
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: mainHue.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: mainHue.surface,
        indicatorColor: colorScheme.primaryContainer,
        indicatorShape: _sharpShape,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: mainHue.surface,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        indicatorShape: _sharpShape,
      ),
      // ── Cards & surfaces ──
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: _sharpShape,
        color: mainHue.raised,
      ),
      dialogTheme: DialogThemeData(
        shape: _sharpShape,
        backgroundColor: mainHue.surface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: _sharpShape,
        backgroundColor: mainHue.surface,
      ),
      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mainHue.raised,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(CrispyRadius.tv)),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: _sharpShape,
        backgroundColor: mainHue.raised,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      // ── Buttons (all sharp) ──
      elevatedButtonTheme: ct.elevatedButton,
      filledButtonTheme: ct.filledButton,
      outlinedButtonTheme: ct.outlinedButton,
      textButtonTheme: ct.textButton,
      // ── Chips, menus, toggles ──
      chipTheme: ct.chip,
      popupMenuTheme: ct.popupMenu,
      menuTheme: ct.menu,
      segmentedButtonTheme: ct.segmentedButton,
      toggleButtonsTheme: ct.toggleButtons,
      // ── List & FAB ──
      listTileTheme: ct.listTile,
      floatingActionButtonTheme: ct.fab,
    );
  }

  /// Builds dark theme from seed color (legacy path).
  static ThemeData _buildTheme(Color seedColor) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    // Strict Cinematic Dark Mode Overrides
    final colorScheme = baseColorScheme.copyWith(
      surface: CrispyColors.bgSurface,
      onSurface: const Color(0xFFFFFFFF),
      surfaceContainer: CrispyColors.bgSurfaceLight,
      primary: seedColor,
    );

    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme =
        useGoogleFonts
            ? GoogleFonts.interTextTheme(baseTextTheme)
            : baseTextTheme;

    final crispyColors = CrispyColors.dark();
    final ct = _sharpComponentThemes(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CrispyColors.bgImmersive,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: textTheme,
      pageTransitionsTheme: _pageTransitions,
      extensions: <ThemeExtension<dynamic>>[crispyColors],
      // ── App chrome ──
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: CrispyColors.bgSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CrispyColors.bgSurface,
        indicatorColor: colorScheme.primaryContainer,
        indicatorShape: _sharpShape,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: CrispyColors.bgSurface,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        indicatorShape: _sharpShape,
      ),
      // ── Cards & surfaces ──
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: _sharpShape,
        color: CrispyColors.bgSurface,
      ),
      dialogTheme: const DialogThemeData(
        shape: _sharpShape,
        backgroundColor: CrispyColors.bgSurface,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: _sharpShape,
        backgroundColor: CrispyColors.bgSurface,
      ),
      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CrispyColors.bgSurfaceLight,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(CrispyRadius.tv)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(CrispyRadius.tv),
          ),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: _sharpShape,
        backgroundColor: CrispyColors.bgSurfaceLight,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      // ── Buttons (all sharp) ──
      elevatedButtonTheme: ct.elevatedButton,
      filledButtonTheme: ct.filledButton,
      outlinedButtonTheme: ct.outlinedButton,
      textButtonTheme: ct.textButton,
      // ── Chips, menus, toggles ──
      chipTheme: ct.chip,
      popupMenuTheme: ct.popupMenu,
      menuTheme: ct.menu,
      segmentedButtonTheme: ct.segmentedButton,
      toggleButtonsTheme: ct.toggleButtons,
      // ── List & FAB ──
      listTileTheme: ct.listTile,
      floatingActionButtonTheme: ct.fab,
    );
  }
}

/// Holds references to all sharp-cornered component themes.
class _ComponentThemes {
  const _ComponentThemes({
    required this.elevatedButton,
    required this.filledButton,
    required this.outlinedButton,
    required this.textButton,
    required this.chip,
    required this.popupMenu,
    required this.menu,
    required this.segmentedButton,
    required this.toggleButtons,
    required this.listTile,
    required this.fab,
  });

  final ElevatedButtonThemeData elevatedButton;
  final FilledButtonThemeData filledButton;
  final OutlinedButtonThemeData outlinedButton;
  final TextButtonThemeData textButton;
  final ChipThemeData chip;
  final PopupMenuThemeData popupMenu;
  final MenuThemeData menu;
  final SegmentedButtonThemeData segmentedButton;
  final ToggleButtonsThemeData toggleButtons;
  final ListTileThemeData listTile;
  final FloatingActionButtonThemeData fab;
}
