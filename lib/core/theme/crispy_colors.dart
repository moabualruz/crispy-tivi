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

  /// Cinematic brand red (used for accent highlights).
  static const Color brandRed = Color(0xFFE50914);

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

  /// Status indicator: success / healthy state (Material green-500, #4CAF50).
  ///
  /// Used for source health dots, rating badges (G), and other inline
  /// status indicators that need a vivid success green. Distinct from
  /// [successGreen] which is the darker green-800 used for toast backgrounds.
  static const Color statusSuccess = Color(0xFF4CAF50);

  /// Status indicator: warning / degraded state (Material orange-500, #FF9800).
  ///
  /// Used for source health dots, rating badges (PG-13), and other inline
  /// status indicators that need a vivid warning orange. Distinct from
  /// [warningOrange] which is the darker deep-orange-800 used for toast
  /// backgrounds.
  static const Color statusWarning = Color(0xFFFF9800);

  /// Status indicator: error / offline state (Material red-400, #F44336).
  ///
  /// Used for source health dots and other inline status indicators
  /// that need a vivid error red. For semantic error colors in the theme
  /// use `ColorScheme.error` instead.
  static const Color statusError = Color(0xFFF44336);

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

  // ── Scrim overlay tokens ────────────────────────────────────

  /// Scrim overlay — light (25% black). Used for subtle overlays.
  static const Color scrimLight = Color(0x40000000);

  /// Scrim overlay — medium (50% black). Used for standard overlays.
  static const Color scrimMid = Color(0x80000000);

  /// Scrim overlay — heavy (75% black). Used for modal backdrops.
  static const Color scrimHeavy = Color(0xBF000000);

  /// Scrim overlay — full (90% black). Used for immersive overlays.
  static const Color scrimFull = Color(0xE6000000);

  /// Scrim overlay — 60% black. Used for EPG strip and info panels.
  static const Color scrim60 = Color(0x99000000);

  /// Scrim overlay — 80% black. Used for hero banner bottom fade.
  static const Color scrim80 = Color(0xCC000000);

  // ── OSD panel tokens ──────────────────────────────────────

  /// OSD panel background — 70% black. Used for player OSD strips.
  static const Color osdPanel = Color(0xB3000000);

  /// OSD panel background — dense / 85% dark. Used for compact OSD areas.
  static const Color osdPanelDense = Color(0xD91A1A1A);

  // ── Seek bar tokens ───────────────────────────────────────

  /// Seek bar segment highlight — 50% amber. Used for A-B loop / chapter markers.
  static const Color segmentHighlight = Color(0x80FFB300);

  // ── EPG genre tint overlay tokens ───────────────────────────

  /// EPG genre tint overlay — sports (≈12% opacity green, #4CAF50).
  static const Color genreSports = Color(0x1E4CAF50);

  /// EPG genre tint overlay — news (≈12% opacity blue, #2196F3).
  static const Color genreNews = Color(0x1E2196F3);

  /// EPG genre tint overlay — movie/film (≈12% opacity purple, #9C27B0).
  static const Color genreMovie = Color(0x1E9C27B0);

  /// EPG genre tint overlay — kids/children (≈12% opacity orange, #FF9800).
  static const Color genreKids = Color(0x1EFF9800);

  /// EPG genre tint overlay — music (≈12% opacity pink, #E91E63).
  static const Color genreMusic = Color(0x1EE91E63);

  /// EPG genre tint overlay — documentary (≈12% opacity teal, #009688).
  static const Color genreDocumentary = Color(0x1E009688);

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
