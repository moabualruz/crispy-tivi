import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/accent_color.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import 'profile_service_providers.dart';

/// Returns a [ThemeData] with the active profile's accent color applied.
///
/// When the active profile has no [UserProfile.accentColorValue] set,
/// falls back to the global [ThemeState] (no override).
///
/// Usage — wrap content below the router in a [Theme] widget:
/// ```dart
/// Theme(
///   data: ref.watch(profileAccentThemeProvider),
///   child: child,
/// )
/// ```
final profileAccentThemeProvider = Provider<ThemeData>((ref) {
  final themeState = ref.watch(themeProvider);
  final profileAsync = ref.watch(profileServiceProvider);

  // Resolve the active profile's accent color, if any.
  final accentArgb = profileAsync.whenOrNull(
    data: (state) => state.activeProfile?.accentColorValue,
  );

  if (accentArgb == null) {
    // No per-profile override — build from global theme state.
    return AppTheme.fromThemeState(themeState).theme;
  }

  // Build a modified ThemeState with the profile's accent color.
  final overriddenState = themeState.copyWith(
    accent: AccentColor.custom,
    customAccent: Color(accentArgb),
  );
  return AppTheme.fromThemeState(overriddenState).theme;
});
