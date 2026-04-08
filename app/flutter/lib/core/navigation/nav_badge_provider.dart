import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dvr/data/dvr_service.dart';
import '../../features/vod/presentation/providers/vod_favorites_provider.dart';
import 'app_routes.dart';

/// Badge data for a single navigation destination.
class NavBadge {
  const NavBadge({this.count = 0, this.showDot = false});

  /// Numeric count shown on the badge (0 = hidden).
  final int count;

  /// Dot badge shown when [count] is 0 but something noteworthy exists.
  final bool showDot;

  /// Whether any badge should be rendered.
  bool get isVisible => count > 0 || showDot;
}

/// Aggregated badge state for all navigation items.
class NavBadgeState {
  const NavBadgeState({
    this.dvr = const NavBadge(),
    this.favorites = const NavBadge(),
  });

  /// Badge for the DVR tab — shows active + scheduled recording count.
  final NavBadge dvr;

  /// Badge for the Favorites tab — dot when favorites exist.
  final NavBadge favorites;
}

/// Provider that computes [NavBadgeState] by watching DVR and
/// VOD favorites state.
///
/// DVR badge: count of scheduled + in-progress recordings.
/// Favorites badge: dot when the user has any VOD favorites.
///
/// Both auto-hide when their respective counts reach 0.
final navBadgeProvider = Provider<NavBadgeState>((ref) {
  // ── DVR badge ─────────────────────────────────────────────────────────
  final dvrAsync = ref.watch(dvrServiceProvider);
  final dvrCount = dvrAsync.when(
    data: (state) => state.scheduled.length + state.inProgress.length,
    loading: () => 0,
    error: (_, _) => 0,
  );

  // ── Favorites dot ─────────────────────────────────────────────────────
  final favAsync = ref.watch(vodFavoritesProvider);
  final hasFavorites = favAsync.when(
    data: (ids) => ids.isNotEmpty,
    loading: () => false,
    error: (_, _) => false,
  );

  return NavBadgeState(
    dvr: NavBadge(count: dvrCount),
    favorites: NavBadge(showDot: hasFavorites),
  );
});

// ── FE-AS-09: Content Freshness "NEW" Badges ─────────────────────────────────

/// Tracks the last-visited timestamp per navigation section.
///
/// When content is added after [lastVisited] for a route, the route
/// displays a "NEW" pill badge. The badge disappears on navigation
/// to that section (call [markVisited]).
class NavFreshnessState {
  const NavFreshnessState({this.lastVisited = const {}});

  /// Maps route path → last-visited [DateTime].
  final Map<String, DateTime> lastVisited;

  NavFreshnessState copyWith({Map<String, DateTime>? lastVisited}) {
    return NavFreshnessState(lastVisited: lastVisited ?? this.lastVisited);
  }
}

/// Notifier that manages per-section last-visited timestamps.
///
/// Do NOT use StateProvider — this is a [Notifier] per Riverpod 3.x
/// patterns.
class NavFreshnessNotifier extends Notifier<NavFreshnessState> {
  @override
  NavFreshnessState build() => const NavFreshnessState();

  /// Records the current timestamp as the last-visit time for [route].
  ///
  /// Call this whenever the user navigates to a section.
  void markVisited(String route) {
    final updated = Map<String, DateTime>.from(state.lastVisited);
    updated[route] = DateTime.now();
    state = state.copyWith(lastVisited: updated);
  }

  /// Returns the last-visited [DateTime] for [route], or null if never
  /// visited.
  DateTime? lastVisitedFor(String route) => state.lastVisited[route];

  /// Whether [route] has never been visited in this session.
  bool isNew(String route) => !state.lastVisited.containsKey(route);
}

/// Global provider for nav freshness (last-visited timestamps).
///
/// FE-AS-09: Tracks session-level "new content" status per nav section.
final navFreshnessProvider =
    NotifierProvider<NavFreshnessNotifier, NavFreshnessState>(
      NavFreshnessNotifier.new,
    );

/// Routes that should show a "NEW" badge when not yet visited.
///
/// FE-AS-09: VOD and Series show freshness badges by default.
const Set<String> kFreshnessBadgeRoutes = {AppRoutes.vod, AppRoutes.series};
