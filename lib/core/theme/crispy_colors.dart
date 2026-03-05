import 'dart:ui';

import 'package:flutter/material.dart';

/// Semantic color tokens specific to CrispyTivi that extend
/// Material 3's `ColorScheme`.
///
/// Matches `.ai/docs/project-specs/design_system.md §1.2`. Access via the
/// [CrispyColorsExtension] on [ThemeData]:
///
/// ```dart
/// final rice = Theme.of(context).crispyColors;
/// Container(color: rice.liveRed);
/// ```
@immutable
class CrispyColors extends ThemeExtension<CrispyColors> {
  const CrispyColors({
    required this.liveRed,
    required this.recordingRed,
    required this.epgNowLine,
    required this.glassTint,
    required this.glassBlur,
    required this.epgPastOpacity,
    required this.successColor,
    required this.warningColor,
  });

  /// Default colors (dark-mode only, CrispyTivi does not support light mode).
  factory CrispyColors.dark() => const CrispyColors(
    liveRed: Color(0xFFFF5252),
    recordingRed: Color(0xFFD32F2F),
    epgNowLine: Color(0xFFFF0000),
    glassTint: Color(0xCC1A1A1A), // 80% opacity
    glassBlur: 20.0,
    epgPastOpacity: 0.5,
    successColor: Color(0xFF2E7D32), // Material green-800
    warningColor: Color(0xFFE65100), // Material deep-orange-800
  );

  // ── V2 Cinematic Dark Mode surface tokens ──────────────

  /// Immersive black background (#000000).
  static const Color bgImmersive = Color(0xFF000000);

  /// Primary surface (#121212).
  static const Color bgSurface = Color(0xFF121212);

  /// Raised surface / card (#1E1E1E).
  static const Color bgSurfaceLight = Color(0xFF1E1E1E);

  /// High-emphasis text (#FFFFFF).
  static const Color textHigh = Color(0xFFFFFFFF);

  /// Medium-emphasis text (#B3B3B3).
  static const Color textMed = Color(0xFFB3B3B3);

  /// Disabled text (#404040).
  static const Color textDis = Color(0xFF404040);

  /// Focus border color (white).
  static const Color focusBorder = Color(0xFFFFFFFF);

  /// Netflix-style brand red (used for accent highlights).
  static const Color netflixRed = Color(0xFFE50914);

  /// Toast / status indicator: success state background (static alias).
  ///
  /// Matches [CrispyColors.successColor] from the dark theme factory.
  /// Use the instance field via [crispyColors] when inside a widget tree;
  /// use this constant when a [BuildContext] is not available.
  static const Color successGreen = Color(0xFF2E7D32); // Material green-800

  /// Toast / status indicator: warning state background (static alias).
  ///
  /// Matches [CrispyColors.warningColor] from the dark theme factory.
  /// Use the instance field via [crispyColors] when inside a widget tree;
  /// use this constant when a [BuildContext] is not available.
  static const Color warningOrange = Color(
    0xFFE65100,
  ); // Material deep-orange-800

  /// Highlight / accent amber — used for active-state indicators such as
  /// A-B loop markers, category favorite stars, and lock-screen icons.
  ///
  /// Equivalent to `Colors.amber` (Material amber-500, #FFC107).
  static const Color highlightAmber = Color(0xFFFFC107);

  // ── Cinematic vignette gradient tokens ─────────────────────

  /// Semi-transparent black for vignette gradient mid-stop (50% opacity).
  ///
  /// Used in cinematic hero banners and series hero headers as the
  /// start of the bottom fade gradient.
  static const Color vignetteStart = Color(0x80000000);

  /// Near-opaque black for vignette gradient end-stop (90% opacity).
  ///
  /// Used in cinematic hero banners and series hero headers as the
  /// near-black step before full black.
  static const Color vignetteEnd = Color(0xE6000000);

  // ── Shared hex-parse utility ──────────────────────────────

  /// Parses a hex color string (with or without `#` prefix, 6 or 8 digits)
  /// into a [Color].
  ///
  /// Shared by `AppTheme` and `ThemeProvider` to avoid duplication.
  ///
  /// - `'#3B82F6'` → opaque blue
  /// - `'FF3B82F6'` → same (ARGB)
  static Color parseHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  /// LIVE indicator pulsing badge.
  final Color liveRed;

  /// Recording-in-progress indicator.
  final Color recordingRed;

  /// EPG now-line vertical bar.
  final Color epgNowLine;

  /// Glassmorphic surface tint overlay.
  final Color glassTint;

  /// Blur sigma for glassmorphic surfaces.
  final double glassBlur;

  /// Opacity multiplier for past EPG programs.
  final double epgPastOpacity;

  /// Toast / status indicator: success state background.
  ///
  /// Used by [ToastOverlay] for `ToastType.success` and any widget
  /// showing a positive/success state. Matches Material green-800.
  final Color successColor;

  /// Toast / status indicator: warning state background.
  ///
  /// Used by [ToastOverlay] for `ToastType.warning` and any widget
  /// showing a cautionary/warning state. Matches Material orange-800.
  final Color warningColor;

  @override
  CrispyColors copyWith({
    Color? liveRed,
    Color? recordingRed,
    Color? epgNowLine,
    Color? glassTint,
    double? glassBlur,
    double? epgPastOpacity,
    Color? successColor,
    Color? warningColor,
  }) {
    return CrispyColors(
      liveRed: liveRed ?? this.liveRed,
      recordingRed: recordingRed ?? this.recordingRed,
      epgNowLine: epgNowLine ?? this.epgNowLine,
      glassTint: glassTint ?? this.glassTint,
      glassBlur: glassBlur ?? this.glassBlur,
      epgPastOpacity: epgPastOpacity ?? this.epgPastOpacity,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
    );
  }

  @override
  CrispyColors lerp(covariant ThemeExtension<CrispyColors>? other, double t) {
    if (other is! CrispyColors) return this;
    return CrispyColors(
      liveRed: Color.lerp(liveRed, other.liveRed, t)!,
      recordingRed: Color.lerp(recordingRed, other.recordingRed, t)!,
      epgNowLine: Color.lerp(epgNowLine, other.epgNowLine, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t) ?? glassBlur,
      epgPastOpacity:
          lerpDouble(epgPastOpacity, other.epgPastOpacity, t) ?? epgPastOpacity,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
    );
  }
}

/// Convenience extension to access [CrispyColors] from [ThemeData].
///
/// ```dart
/// Theme.of(context).crispyColors.liveRed
/// ```
extension CrispyColorsExtension on ThemeData {
  /// Returns the [CrispyColors] for the current theme, falling
  /// back to dark-mode defaults if not set.
  CrispyColors get crispyColors =>
      extension<CrispyColors>() ?? CrispyColors.dark();
}
