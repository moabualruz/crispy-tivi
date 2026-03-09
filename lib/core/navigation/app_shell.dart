import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/presentation/widgets/toast_overlay.dart';
import '../../features/player/presentation/providers/player_providers.dart';
import '../../features/player/presentation/widgets/mini_player_bar.dart';
import '../../features/player/presentation/widgets/permanent_video_layer.dart';
import '../../features/player/presentation/widgets/player_fullscreen_overlay.dart';
import '../../features/profiles/data/profile_service.dart';
import '../../features/profiles/presentation/profile_constants.dart';
import '../../features/profiles/presentation/providers/profile_theme_provider.dart';
import '../theme/crispy_animation.dart';
import '../widgets/async_value_ui.dart';
import '../theme/crispy_radius.dart';
import '../widgets/crispy_title_bar.dart';
import '../widgets/offline_banner.dart';
import '../utils/keyboard_utils.dart';
import '../widgets/responsive_layout.dart';
import 'app_routes.dart';
import 'breadcrumb_bar.dart';
import '../testing/test_keys.dart';
import 'nav_badge_provider.dart';
import 'nav_destinations.dart';
import 'section_fab_provider.dart';
import 'shell_providers.dart';
import 'side_nav.dart';

/// Adaptive navigation shell with player-first architecture.
///
/// The video player is the foundation layer — always mounted
/// as [PermanentVideoLayer] at layer 0 of a [Stack]. Screen
/// content overlays on top. Fullscreen hides screens and shows
/// [PlayerOsdLayer].
///
/// Navigation layout:
/// - **Compact/Medium** (< 840 dp): Bottom navigation bar
/// - **Expanded/Large** (>= 840 dp): Side navigation rail
class AppShell extends ConsumerStatefulWidget {
  /// Creates the app shell.
  const AppShell({required this.child, super.key});

  /// The currently-routed child widget.
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final FocusScopeNode _contentFocusScope = FocusScopeNode();
  String? _lastReportedPath;

  /// When true, screen content subtree is fully offstage
  /// (zero layout + zero paint). Set after the fade-out
  /// animation completes on fullscreen entry.
  bool _contentOffstage = false;

  /// Tracks whether the side navigation rail is currently extended
  /// (hover or keyboard focus). Used to show the overlay scrim.
  bool _railExtended = false;

  // Shortcut map is rebuilt per build() since it depends on current route
  // (digit keys disabled on channel screen for direct-dial).

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _contentFocusScope.dispose();
    super.dispose();
  }

  int _currentIndex(BuildContext context, List<NavItem> destinations) {
    final location = GoRouterState.of(context).uri.path;
    final index = destinations.indexWhere(
      (d) => location == d.route || location.startsWith('${d.route}/'),
    );
    return index >= 0 ? index : 0;
  }

  void _onDestinationSelected(
    BuildContext context,
    int index,
    List<NavItem> destinations,
  ) {
    final route = destinations[index].route;
    _stopPreviewIfLeaving(route);
    // FE-AS-09: mark section as visited so freshness badge clears.
    ref.read(navFreshnessProvider.notifier).markVisited(route);
    context.go(route);
  }

  void _openSearch(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location != AppRoutes.customSearch) {
      _stopPreviewIfLeaving(AppRoutes.customSearch);
      // Defer navigation to avoid "pop during build" on rapid key presses.
      Future.microtask(() {
        if (context.mounted) context.go(AppRoutes.customSearch);
      });
    }
  }

  /// Delegates to [PlayerModeNotifier.stopPreviewIfLeavingRoute]
  /// which handles both the stop decision and route update.
  /// Called synchronously before [context.go] so the platform
  /// view is removed before the new route's first frame renders.
  void _stopPreviewIfLeaving(String targetRoute) {
    ref
        .read(playerModeProvider.notifier)
        .stopPreviewIfLeavingRoute(
          targetRoute,
          stopPlayback: ref.read(playerServiceProvider).stop,
        );
  }

  /// Builds the keyboard shortcut map for the given layout mode.
  Map<ShortcutActivator, VoidCallback> _shortcutsFor(
    BuildContext context,
    bool usesSideNav,
  ) {
    const digitKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];

    final navDests = usesSideNav ? sideDestinations : bottomDestinations;
    final map = <ShortcutActivator, VoidCallback>{
      // Search: / or Ctrl+K
      const SingleActivator(LogicalKeyboardKey.slash):
          () => _openSearch(context),
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          () => _openSearch(context),
      // Back: Escape, GoBack, Gamepad B
      const SingleActivator(LogicalKeyboardKey.escape):
          () => _handleBack(context),
      const SingleActivator(LogicalKeyboardKey.goBack):
          () => _handleBack(context),
      const SingleActivator(LogicalKeyboardKey.gameButtonB):
          () => _handleBack(context),
    };

    // Digit shortcuts disabled on channel screen so ChannelTvLayout
    // direct-dial (channel number jump) can receive digit key events.
    final currentPath = GoRouterState.of(context).uri.path;
    final isChannelScreen = currentPath.startsWith(AppRoutes.tv);

    if (!isChannelScreen) {
      for (var i = 0; i < navDests.length && i < digitKeys.length; i++) {
        map[SingleActivator(digitKeys[i])] = () {
          _stopPreviewIfLeaving(navDests[i].route);
          // FE-AS-09: mark section visited via keyboard shortcut too.
          ref
              .read(navFreshnessProvider.notifier)
              .markVisited(navDests[i].route);
          Future.microtask(() {
            if (context.mounted) context.go(navDests[i].route);
          });
        };
      }
    }

    return map;
  }

  /// Returns the context-aware [FloatingActionButton] for the current
  /// route, or `null` when no FAB is appropriate.
  ///
  /// FE-AS-11: The FAB is context-aware per nav section on phone layout.
  ///
  /// | Route       | FAB (legacy/hard-coded)      | Phone FAB (section) |
  /// |-------------|------------------------------|---------------------|
  /// | `/tv`       | Record (red dot)             | Last Channel        |
  /// | `/dvr`      | Schedule (calendar)          | —                   |
  /// | `/favorites`| New List (add)               | —                   |
  /// | `/home`     | —                            | What's On           |
  /// | `/vods`     | —                            | Random Pick         |
  /// | others      | none                         | none                |
  ///
  /// The FAB is suppressed on TV/large layout (`usesSideNav && isLarge`)
  /// because D-pad users navigate with shoulder buttons instead.
  Widget? _buildFab(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final colorScheme = Theme.of(context).colorScheme;
    final isLarge = context.isLarge;

    // Suppress FAB entirely on large/TV layout.
    if (isLarge) return null;

    // ── Legacy section FABs (DVR / Favorites keep their dedicated actions) ──
    final legacyFab = switch (location) {
      AppRoutes.dvr => FloatingActionButton.extended(
        heroTag: 'fab_schedule',
        onPressed: () {},
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CrispyRadius.tv)),
        ),
        icon: const Icon(Icons.calendar_month_rounded),
        label: Text(context.l10n.fabSchedule),
      ),
      AppRoutes.favorites => FloatingActionButton.extended(
        heroTag: 'fab_new_list',
        onPressed: () {},
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CrispyRadius.tv)),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.fabNewList),
      ),
      _ => null,
    };

    if (legacyFab != null) return legacyFab;

    // FE-AS-11: Context-aware FAB for phone layout.
    // Look up any registered callback from [sectionFabProvider].
    final registeredCallback = ref.watch(sectionFabProvider)[location];
    final fabConfig = fabConfigForRoute(location, () => _openSearch(context));
    if (fabConfig == null) return null;

    final onPressed = registeredCallback ?? fabConfig.onPressed;

    return FloatingActionButton.extended(
      // FE-AS-11: section FAB with primaryContainer styling.
      heroTag: fabConfig.heroTag,
      onPressed: onPressed,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(CrispyRadius.tv)),
      ),
      icon: Icon(fabConfig.icon),
      label: Text(fabConfig.label),
    );
  }

  /// Handle Escape / Back / Gamepad-B.
  ///
  /// In fullscreen: exit to preview/background.
  /// Otherwise: pop navigation or go Home.
  void _handleBack(BuildContext context) {
    final mode = ref.read(playerModeProvider).mode;
    if (mode == PlayerMode.fullscreen) {
      final screenSize = MediaQuery.sizeOf(context);
      ref
          .read(playerModeProvider.notifier)
          .exitToPreview(screenSize: screenSize);
      ref.read(playerServiceProvider).forceStateEmit();
      return;
    }
    // Two-stage escape: first unfocus any active text field,
    // second press pops the screen.
    if (tryUnfocusTextFieldFirst()) return;
    // Defer navigation to avoid "pop during build" on rapid key presses.
    Future.microtask(() {
      if (!context.mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        final location = GoRouterState.of(context).uri.path;
        if (location != AppRoutes.home) {
          context.go(AppRoutes.home);
        }
      }
    });
  }

  /// Wraps [icon] in a Material 3 [Badge] when [badge] warrants one.
  ///
  /// - Count > 0 → numeric badge with [colorScheme.error] background.
  /// - Dot only  → 6 dp unlabelled dot.
  /// - No badge  → returns [icon] unchanged.
  static Widget _badgedIcon(Widget icon, NavBadge? badge, ColorScheme cs) {
    if (badge == null || !badge.isVisible) return icon;
    if (badge.count > 0) {
      return Badge(
        label: Text('${badge.count}'),
        backgroundColor: cs.error,
        textColor: cs.onError,
        child: icon,
      );
    }
    return Badge(smallSize: 6, backgroundColor: cs.error, child: icon);
  }

  @override
  Widget build(BuildContext context) {
    final usesSideNav = context.usesSideNav;
    // FE-PM-08: Apply per-profile accent color override.
    final profileTheme = ref.watch(profileAccentThemeProvider);
    final colorScheme = profileTheme.colorScheme;
    final isFullscreen =
        ref.watch(playerModeProvider.select((s) => s.mode)) ==
        PlayerMode.fullscreen;

    // Two-phase fullscreen transition:
    // Phase 1: AnimatedOpacity fades content to 0 (300ms).
    // Phase 2: Offstage removes content from layout + paint.
    // On exit: immediately undo Offstage (video still covers).
    ref.listen(playerModeProvider.select((s) => s.mode), (prev, next) {
      if (next == PlayerMode.fullscreen) {
        Future.delayed(CrispyAnimation.normal, () {
          if (mounted && !_contentOffstage) {
            setState(() => _contentOffstage = true);
          }
        });
      } else if (_contentOffstage) {
        setState(() => _contentOffstage = false);
      }
    });
    // Handle case where mode is already fullscreen on first
    // mount (e.g. auto-resume set fullscreen before AppShell
    // mounted). ref.listen only fires on change, not initial.
    if (isFullscreen && !_contentOffstage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_contentOffstage) {
          Future.delayed(CrispyAnimation.normal, () {
            if (mounted && !_contentOffstage) {
              setState(() => _contentOffstage = true);
            }
          });
        }
      });
    }

    // Track the current route so PermanentVideoLayer can
    // hide the video when navigating away from the host screen.
    final currentPath = GoRouterState.of(context).uri.path;
    // Schedule after frame only when the route actually changed.
    if (_lastReportedPath != currentPath) {
      _lastReportedPath = currentPath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(playerModeProvider.notifier).updateCurrentRoute(currentPath);
        }
      });
    }

    // Global keyboard shortcuts — disabled during fullscreen
    // so PlayerFullscreenOverlay's KeyboardListener handles
    // all input (Escape for zap dismiss, digits for seek, etc.).
    // The map is memoized by [_shortcutsFor] to avoid per-frame allocs.
    final baseShortcuts =
        isFullscreen
            ? const <ShortcutActivator, VoidCallback>{}
            : _shortcutsFor(context, usesSideNav);

    final shortcuts = baseShortcuts;

    return Theme(
      data: profileTheme,
      child: CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          autofocus: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Black backdrop ──
              // Prevents the white window background from
              // bleeding through during the crossfade between
              // content fading out and video fading in.
              if (isFullscreen) const ColoredBox(color: Colors.black),

              // ── Layer 0: Screen content ──
              // Offstage after fade-out completes — zero layout
              // + zero paint during fullscreen playback.
              // RepaintBoundary isolates content repaints from
              // video compositing layer.
              RepaintBoundary(
                child: Offstage(
                  offstage: _contentOffstage,
                  child: AnimatedOpacity(
                    duration: CrispyAnimation.normal,
                    opacity: isFullscreen ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: isFullscreen,
                      child:
                          usesSideNav
                              ? _buildRailLayout(context, colorScheme)
                              : _buildBottomNavLayout(context, colorScheme),
                    ),
                  ),
                ),
              ),

              // ── Layer 1: Video (always mounted, on top of content) ──
              const PermanentVideoLayer(),

              // ── Layer 2: Fullscreen overlay (OSD + gestures + keyboard) ──
              // Material ancestor required to prevent yellow double-underline
              // on Text widgets (Flutter's missing-Material debug signal).
              // RepaintBoundary isolates OSD repaints from video layer.
              if (isFullscreen)
                const RepaintBoundary(
                  child: Material(
                    type: MaterialType.transparency,
                    child: PlayerFullscreenOverlay(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the side-rail layout for expanded/large screens (>= 840 dp).
  Widget _buildRailLayout(BuildContext context, ColorScheme colorScheme) {
    final selectedIndex = _currentIndex(context, sideDestinations);
    final isLoading = ref.watch(globalLoadingProvider);
    // TV (large >= 1200 dp) always shows labels without hover.
    final isTv = context.isLarge;
    // FAB is suppressed on TV — D-pad users have dedicated shortcuts.
    final fab = isTv ? null : _buildFab(context);

    return Scaffold(
      key: TestKeys.appShell,
      floatingActionButton: fab,
      body: Column(
        children: [
          const CrispyTitleBar(),
          Expanded(
            child: Stack(
              children: [
                // ── Content area (start-padded for collapsed rail) ──
                // Content always uses full width minus the collapsed
                // rail. When the rail expands on hover/focus it
                // overlays content instead of pushing it aside.
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: kRailCollapsedWidth,
                  ),
                  child: FocusTraversalGroup(
                    child: FocusScope(
                      node: _contentFocusScope,
                      child: Column(
                        children: [
                          // ── FE-AS-07: Offline banner ───────────
                          const OfflineBanner(),
                          // ── FE-AS-13: Breadcrumb bar ───────────
                          const BreadcrumbBar(),
                          Expanded(child: ToastOverlay(child: widget.child)),
                          const MiniPlayerBar(),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Scrim when rail is expanded ──────────────────────
                // Dims content behind the expanded rail overlay.
                IgnorePointer(
                  ignoring: !_railExtended,
                  child: AnimatedOpacity(
                    duration: CrispyAnimation.fast,
                    opacity: _railExtended ? 1.0 : 0.0,
                    child: const ColoredBox(color: Colors.black26),
                  ),
                ),

                // ── Navigation rail (overlays at start edge) ─────────
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RailNavWidget(
                        selectedIndex: selectedIndex,
                        onDestinationSelected:
                            (i) => _onDestinationSelected(
                              context,
                              i,
                              sideDestinations,
                            ),
                        onExtendedChanged: (extended) {
                          if (_railExtended != extended) {
                            setState(() => _railExtended = extended);
                          }
                        },
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: colorScheme.outlineVariant,
                      ),
                    ],
                  ),
                ),

                // ── Global loading indicator (FE-AS-14) ───────────────
                if (isLoading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // FE-AS-10: Routes that use horizontal scrolling (EPG timeline, search filter
  // chip row). Swipe is disabled on these to avoid gesture conflicts.
  static const Set<String> _kSwipeDisabledRoutes = {
    AppRoutes.epg,
    AppRoutes.customSearch,
  };

  /// Returns true when swipe-between-sections should be active.
  ///
  /// FE-AS-10: Disabled on routes with their own horizontal scroll.
  bool _swipeEnabled(String location) =>
      !_kSwipeDisabledRoutes.any(
        (r) => location == r || location.startsWith('$r/'),
      );

  /// Handles horizontal swipe to navigate between bottom-nav sections.
  ///
  /// FE-AS-10: Left swipe → next section, right swipe → previous section.
  void _onHorizontalSwipe(
    BuildContext context,
    DragEndDetails details,
    int currentIndex,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    // Threshold: 300 dp/s to filter accidental micro-swipes.
    if (velocity.abs() < 300) return;

    final destinations = bottomDestinations;
    int nextIndex;
    if (velocity < 0) {
      // Swipe left → next section.
      nextIndex = (currentIndex + 1).clamp(0, destinations.length - 1);
    } else {
      // Swipe right → previous section.
      nextIndex = (currentIndex - 1).clamp(0, destinations.length - 1);
    }

    if (nextIndex == currentIndex) return;
    _onDestinationSelected(context, nextIndex, destinations);
  }

  /// Builds the bottom-nav layout for compact/medium screens (< 840 dp).
  Widget _buildBottomNavLayout(BuildContext context, ColorScheme colorScheme) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _currentIndex(context, bottomDestinations);
    final isLoading = ref.watch(globalLoadingProvider);
    final fab = _buildFab(context);

    // FE-AS-10: Only attach swipe detector on routes without horizontal scroll.
    final swipeActive = _swipeEnabled(location);

    Widget content = Column(
      children: [
        // ── FE-AS-07: Offline banner ───────────────────────
        const OfflineBanner(),
        // ── FE-AS-13: Breadcrumb bar ───────────────────────
        const BreadcrumbBar(),
        Expanded(child: ToastOverlay(child: widget.child)),
        const MiniPlayerBar(),
      ],
    );

    // FE-AS-10: Wrap content in a GestureDetector for horizontal swipe.
    if (swipeActive) {
      content = GestureDetector(
        onHorizontalDragEnd:
            (details) => _onHorizontalSwipe(context, details, selectedIndex),
        // Use HitTestBehavior.deferToChild so the gesture doesn't swallow
        // taps or vertical scrolls that originate from children.
        behavior: HitTestBehavior.deferToChild,
        child: content,
      );
    }

    return Scaffold(
      key: TestKeys.appShell,
      floatingActionButton: fab,
      body: Column(
        children: [
          const CrispyTitleBar(),
          Expanded(
            child: Stack(
              children: [
                content,

                // ── Global loading indicator (FE-AS-14) ───────────────
                if (isLoading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),

                // ── Compact profile avatar (FE-AS-02 / FE-AS-04) ────────
                // Positioned at the top-right so it overlays the screen's
                // AppBar area without replacing it. Tap opens the profile
                // switcher sheet.
                Positioned(
                  top: MediaQuery.of(context).padding.top + 4,
                  right: 4,
                  child: _CompactProfileAvatar(colorScheme: colorScheme),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FocusTraversalGroup(
        child: Consumer(
          builder: (context, ref, _) {
            final badges = ref.watch(navBadgeProvider);
            // FE-AS-09: watch freshness for bottom nav "NEW" badges.
            final freshness = ref.watch(navFreshnessProvider);
            final cs = Theme.of(context).colorScheme;
            return NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected:
                  (i) => _onDestinationSelected(context, i, bottomDestinations),
              destinations:
                  bottomDestinations.map((d) {
                    final badge = switch (d.route) {
                      AppRoutes.dvr => badges.dvr,
                      AppRoutes.favorites => badges.favorites,
                      _ => null,
                    };
                    // FE-AS-09: show "NEW" dot badge on freshness routes.
                    final isNew =
                        kFreshnessBadgeRoutes.contains(d.route) &&
                        freshness.lastVisited[d.route] == null;
                    Widget icon = _badgedIcon(Icon(d.icon), badge, cs);
                    Widget selectedIcon = _badgedIcon(
                      Icon(d.selectedIcon),
                      badge,
                      cs,
                    );
                    if (isNew) {
                      icon = Badge(
                        label: const Text('NEW'),
                        backgroundColor: cs.tertiary,
                        textColor: cs.onTertiary,
                        child: icon,
                      );
                    }
                    return NavigationDestination(
                      key: TestKeys.navItem(d.label),
                      icon: icon,
                      selectedIcon: selectedIcon,
                      label: d.label,
                    );
                  }).toList(),
            );
          },
        ),
      ),
    );
  }
}

// ── Compact profile avatar (FE-AS-02 / FE-AS-04) ─────────────────────────────

/// Small avatar button shown in the top-right corner of the compact
/// (mobile) layout. Tapping opens [ProfileSwitcherSheet].
class _CompactProfileAvatar extends ConsumerWidget {
  const _CompactProfileAvatar({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileServiceProvider);

    return profileAsync.whenShrink(
      data: (state) {
        final profile = state.activeProfile;
        if (profile == null) return const SizedBox.shrink();
        final avatarIcon =
            kProfileAvatarIcons[profile.avatarIndex %
                kProfileAvatarIcons.length];
        final avatarColor =
            kProfileAvatarColors[profile.avatarIndex %
                kProfileAvatarColors.length];
        final hasMultipleProfiles = state.profiles.length > 1;

        return Tooltip(
          message: profile.name,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(CrispyRadius.xl),
              onTap:
                  hasMultipleProfiles
                      ? () => ProfileSwitcherSheet.show(context)
                      : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: profileAvatarGradient(avatarColor),
                  shape: BoxShape.circle,
                ),
                child: Icon(avatarIcon, size: 20, color: colorScheme.onPrimary),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Rail navigation (extracted for rebuild isolation) ──────────────────────────

/// Encapsulates rail hover/focus state so changes rebuild only
/// the rail — not the entire [AppShell] subtree.
class _RailNavWidget extends StatefulWidget {
  const _RailNavWidget({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onExtendedChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Called when the rail's extended state changes (hover/focus).
  final ValueChanged<bool>? onExtendedChanged;

  @override
  State<_RailNavWidget> createState() => _RailNavWidgetState();
}

class _RailNavWidgetState extends State<_RailNavWidget> {
  final FocusScopeNode _railFocusScope = FocusScopeNode();
  bool _isHovering = false;
  bool _isFocused = false;
  bool get _isExtended => _isHovering || _isFocused;

  @override
  void initState() {
    super.initState();
    _railFocusScope.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _railFocusScope.removeListener(_onFocusChange);
    _railFocusScope.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _railFocusScope.hasFocus;
    if (_isFocused != hasFocus) {
      setState(() => _isFocused = hasFocus);
      widget.onExtendedChanged?.call(_isExtended);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovering = true);
          widget.onExtendedChanged?.call(_isExtended);
        },
        onExit: (_) {
          setState(() => _isHovering = false);
          widget.onExtendedChanged?.call(_isExtended);
        },
        child: FocusScope(
          node: _railFocusScope,
          child: SideNav(
            extended: _isExtended,
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            destinations: sideDestinations,
          ),
        ),
      ),
    );
  }
}
