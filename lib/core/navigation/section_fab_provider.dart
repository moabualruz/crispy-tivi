import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_routes.dart';

// ── FE-AS-11: Context-aware FAB config ───────────────────────────────────────

/// Configuration for a context-aware Floating Action Button.
///
/// Each nav section provides its own [SectionFabConfig] when a FAB
/// is appropriate. Sections without a config return null.
class SectionFabConfig {
  const SectionFabConfig({
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// Unique hero tag to prevent animation conflicts between FABs.
  final String heroTag;

  /// FAB icon.
  final IconData icon;

  /// Short label displayed on the extended FAB.
  final String label;

  /// Action invoked on FAB tap.
  final VoidCallback onPressed;
}

/// Maps the current route to a [SectionFabConfig].
///
/// FE-AS-11: Returns null when no FAB is appropriate for a route
/// (e.g. Settings has no FAB on phone layout — use search shortcut
/// instead of a FAB).
SectionFabConfig? fabConfigForRoute(String route, VoidCallback onSearch) {
  return switch (route) {
    // Home: "What's On" quick tune — surfaces the current EPG row.
    AppRoutes.home => const SectionFabConfig(
      heroTag: 'fab_whats_on',
      icon: Icons.live_tv_rounded,
      label: "What's On",
      onPressed: _noOp,
    ),
    // VOD: "Random Pick" — navigates to a random VOD item.
    AppRoutes.vod => const SectionFabConfig(
      heroTag: 'fab_random_pick',
      icon: Icons.shuffle_rounded,
      label: 'Random Pick',
      onPressed: _noOp,
    ),
    // Live TV: "Last channel" — resumes the previously tuned channel.
    AppRoutes.tv => const SectionFabConfig(
      heroTag: 'fab_last_channel',
      icon: Icons.replay_rounded,
      label: 'Last Channel',
      onPressed: _noOp,
    ),
    // No FAB for other routes.
    _ => null,
  };
}

void _noOp() {}

/// Riverpod state for the context-aware FAB.
///
/// FE-AS-11: Notifier that holds FAB visibility and action callbacks.
/// The [AppShell] uses [currentRouteProvider] to derive the config at
/// build time; this notifier allows screens to register custom callbacks.
class SectionFabNotifier extends Notifier<Map<String, VoidCallback>> {
  @override
  Map<String, VoidCallback> build() => {};

  /// Registers a callback for [route]'s FAB action.
  ///
  /// Call from the relevant screen's [initState] or provider listener.
  /// The [AppShell] reads this map and overrides [_noOp] with a real action.
  void register(String route, VoidCallback callback) {
    state = {...state, route: callback};
  }

  /// Removes the callback for [route].
  void unregister(String route) {
    final updated = Map<String, VoidCallback>.from(state);
    updated.remove(route);
    state = updated;
  }

  /// Returns the registered callback for [route], or null if none.
  VoidCallback? callbackFor(String route) => state[route];
}

/// Provider for per-section FAB action callbacks.
///
/// FE-AS-11: Screens can register callbacks so the shell FAB delegates
/// to the correct screen action.
final sectionFabProvider =
    NotifierProvider<SectionFabNotifier, Map<String, VoidCallback>>(
      SectionFabNotifier.new,
    );
