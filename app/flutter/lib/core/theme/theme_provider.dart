import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accent_color.dart';
import 'crispy_colors.dart';
import 'main_color_hue.dart';

/// Keys for persisting theme settings.
class _ThemeKeys {
  static const mainHue = 'theme_main_hue';
  static const accent = 'theme_accent';
  static const customAccentHex = 'theme_custom_accent_hex';
  static const textScale = 'theme_text_scale';
  static const density = 'theme_density';
  static const glassOpacity = 'theme_glass_opacity';
}

/// UI density presets.
enum UiDensity {
  /// Compact — tighter spacing, smaller touch targets.
  compact('Compact'),

  /// Standard — default Material spacing.
  standard('Standard'),

  /// Comfortable — larger touch targets, more spacing.
  comfortable('Comfortable');

  const UiDensity(this.label);

  final String label;

  /// Returns the VisualDensity for this preset.
  VisualDensity get visualDensity {
    switch (this) {
      case UiDensity.compact:
        return VisualDensity.compact;
      case UiDensity.standard:
        return VisualDensity.standard;
      case UiDensity.comfortable:
        return VisualDensity.comfortable;
    }
  }
}

/// State representing the current theme configuration.
@immutable
class ThemeState {
  const ThemeState({
    this.mainHue = MainColorHue.warmBlack,
    this.accent = AccentColor.gray,
    this.customAccent,
    this.textScale = 1.0,
    this.density = UiDensity.standard,
    this.glassOpacity = 1.0,
  });

  /// The selected main dark theme base color.
  final MainColorHue mainHue;

  /// The selected accent color preset.
  final AccentColor accent;

  /// Custom accent color (used when [accent] is [AccentColor.custom]).
  final Color? customAccent;

  /// Text scale factor (0.8 = 80%, 1.0 = 100%, 1.2 = 120%, etc.).
  /// Range: 0.8 to 1.4.
  final double textScale;

  /// UI density preset.
  final UiDensity density;

  /// Glass surface opacity/intensity (0.0 = flat, 1.0 = full glass).
  /// Range: 0.0 to 1.0.
  final double glassOpacity;

  /// Returns the effective primary accent color.
  Color get primaryColor =>
      accent.color ?? customAccent ?? AccentColor.blue.color!;

  /// Returns the effective container color.
  Color get primaryContainer => accent.container ?? _darken(primaryColor, 0.3);

  /// Returns the effective on-container color.
  Color get onPrimaryContainer =>
      accent.onContainer ?? _lighten(primaryColor, 0.8);

  /// Surface color from the main hue.
  Color get surface => mainHue.surface;

  /// Raised surface color from the main hue.
  Color get surfaceContainer => mainHue.raised;

  /// Scaffold background from the main hue.
  Color get scaffoldBackground => mainHue.scaffold;

  ThemeState copyWith({
    MainColorHue? mainHue,
    AccentColor? accent,
    Color? customAccent,
    double? textScale,
    UiDensity? density,
    double? glassOpacity,
    bool clearCustomAccent = false,
  }) {
    return ThemeState(
      mainHue: mainHue ?? this.mainHue,
      accent: accent ?? this.accent,
      customAccent:
          clearCustomAccent ? null : (customAccent ?? this.customAccent),
      textScale: textScale ?? this.textScale,
      density: density ?? this.density,
      glassOpacity: glassOpacity ?? this.glassOpacity,
    );
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// Provider for the current theme state.
final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);

/// Manages theme state and persistence.
class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    // Load saved theme preferences asynchronously
    _loadSavedPreferences();
    return const ThemeState();
  }

  /// Loads saved theme preferences from SharedPreferences.
  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final hueIndex = prefs.getInt(_ThemeKeys.mainHue);
      final accentIndex = prefs.getInt(_ThemeKeys.accent);
      final customHex = prefs.getString(_ThemeKeys.customAccentHex);
      final textScale = prefs.getDouble(_ThemeKeys.textScale);
      final densityIndex = prefs.getInt(_ThemeKeys.density);
      final glassOpacity = prefs.getDouble(_ThemeKeys.glassOpacity);

      MainColorHue? mainHue;
      AccentColor? accent;
      Color? customAccent;
      UiDensity? density;

      if (hueIndex != null && hueIndex < MainColorHue.values.length) {
        mainHue = MainColorHue.values[hueIndex];
      }

      if (accentIndex != null && accentIndex < AccentColor.values.length) {
        accent = AccentColor.values[accentIndex];
      }

      if (customHex != null) {
        customAccent = CrispyColors.parseHex(customHex);
      }

      if (densityIndex != null && densityIndex < UiDensity.values.length) {
        density = UiDensity.values[densityIndex];
      }

      if (mainHue != null ||
          accent != null ||
          customAccent != null ||
          textScale != null ||
          density != null ||
          glassOpacity != null) {
        state = state.copyWith(
          mainHue: mainHue,
          accent: accent,
          customAccent: customAccent,
          textScale: textScale,
          density: density,
          glassOpacity: glassOpacity,
        );
      }
    } catch (_) {
      // Ignore load errors, use defaults
    }
  }

  /// Sets the main color hue and persists the choice.
  Future<void> setMainHue(MainColorHue hue) async {
    state = state.copyWith(mainHue: hue);
    await _savePreferences();
  }

  /// Sets the accent color preset and persists the choice.
  Future<void> setAccent(AccentColor accent) async {
    state = state.copyWith(accent: accent);
    await _savePreferences();
  }

  /// Sets a custom accent color and persists the choice.
  Future<void> setCustomAccent(Color color) async {
    state = state.copyWith(accent: AccentColor.custom, customAccent: color);
    await _savePreferences();
  }

  /// Sets the text scale factor and persists the choice.
  ///
  /// Valid range: 0.8 to 1.4 (80% to 140%).
  Future<void> setTextScale(double scale) async {
    final clampedScale = scale.clamp(0.8, 1.4);
    state = state.copyWith(textScale: clampedScale);
    await _savePreferences();
  }

  /// Sets the UI density and persists the choice.
  Future<void> setDensity(UiDensity density) async {
    state = state.copyWith(density: density);
    await _savePreferences();
  }

  /// Sets the glass surface opacity and persists the choice.
  ///
  /// Valid range: 0.0 (flat/opaque) to 1.0 (full glassmorphism).
  Future<void> setGlassOpacity(double opacity) async {
    final clamped = opacity.clamp(0.0, 1.0);
    state = state.copyWith(glassOpacity: clamped);
    await _savePreferences();
  }

  /// Resets theme to defaults.
  Future<void> reset() async {
    state = const ThemeState();
    await _clearPreferences();
  }

  /// Persists current theme settings.
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_ThemeKeys.mainHue, state.mainHue.index);
      await prefs.setInt(_ThemeKeys.accent, state.accent.index);
      await prefs.setDouble(_ThemeKeys.textScale, state.textScale);
      await prefs.setInt(_ThemeKeys.density, state.density.index);
      await prefs.setDouble(_ThemeKeys.glassOpacity, state.glassOpacity);

      if (state.customAccent != null) {
        await prefs.setString(
          _ThemeKeys.customAccentHex,
          _toHex(state.customAccent!),
        );
      } else {
        await prefs.remove(_ThemeKeys.customAccentHex);
      }
    } catch (_) {
      // Ignore save errors
    }
  }

  /// Clears saved theme preferences.
  Future<void> _clearPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ThemeKeys.mainHue);
      await prefs.remove(_ThemeKeys.accent);
      await prefs.remove(_ThemeKeys.customAccentHex);
      await prefs.remove(_ThemeKeys.textScale);
      await prefs.remove(_ThemeKeys.density);
      await prefs.remove(_ThemeKeys.glassOpacity);
    } catch (_) {
      // Ignore clear errors
    }
  }

  static String _toHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}
