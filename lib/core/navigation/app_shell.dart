import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/iptv/application/playlist_sync_service.dart';
import '../../features/notifications/presentation/widgets/toast_overlay.dart';
import '../../features/player/presentation/providers/player_providers.dart';
import '../../features/player/presentation/widgets/mini_player_bar.dart';
import '../../features/player/presentation/widgets/permanent_video_layer.dart';
import '../../features/player/presentation/widgets/player_fullscreen_overlay.dart';
import '../../features/profiles/data/profile_service.dart';
import '../../features/profiles/presentation/profile_constants.dart';
import '../../features/profiles/presentation/providers/profile_theme_provider.dart';
import '../theme/crispy_animation.dart';
import '../utils/focus_restoration_service.dart';
import '../widgets/async_value_ui.dart';
import '../theme/crispy_radius.dart';
import '../widgets/crispy_title_bar.dart';
import '../widgets/focus_restoring_dialog.dart';
import '../widgets/offline_banner.dart';
import '../utils/device_form_factor.dart';
import '../utils/keyboard_utils.dart';
import '../widgets/keyboard_shortcuts_overlay.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/tv_remote_key_handler.dart';
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
      // Home key: panic shortcut — navigate to Home from anywhere.
      const SingleActivator(LogicalKeyboardKey.home): () {
        Future.microtask(() {
          if (context.mounted) {
            _stopPreviewIfLeaving(AppRoutes.home);
            context.go(AppRoutes.home);
          }
        });
      },
      // Search: / or Ctrl+K
      const SingleActivator(LogicalKeyboardKey.slash):
          () => _openSearch(context),
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          () => _openSearch(context),
      // Keyboard shortcuts overlay: ? (Shift+/)
      // Only on desktop/web — TV and mobile don't use keyboard shortcuts.
      if (!DeviceFormFactorService.current.isTV &&
          !DeviceFormFactorService.current.isMobile)
        const SingleActivator(LogicalKeyboardKey.slash, shift: true):
            () => showKeyboardShortcutsOverlay(context),
      // Back: Escape, GoBack, BrowserBack, Gamepad B
      // NOTE: Backspace is handled in _onKeyEvent (not here) so it
      // doesn't get swallowed when a TextField is focused.
      const SingleActivator(LogicalKeyboardKey.escape):
          () => _handleBack(context),
      const SingleActivator(LogicalKeyboardKey.goBack):
          () => _handleBack(context),
      const SingleActivator(LogicalKeyboardKey.browserBack):
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

  /// Handles Backspace as back-navigation only when no text field is focused.
  ///
  /// This is handled here (instead of in [CallbackShortcuts]) because
  /// [CallbackShortcuts] would swallow the Backspace event before the
  /// child [TextField] can process it for text editing.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Backspace as back-navigation (only when no text field is focused).
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      final primaryFocus = FocusManager.instance.primaryFocus;
      if (primaryFocus != null &&
          primaryFocus.context?.findAncestorWidgetOfExactType<EditableText>() !=
              null) {
        return KeyEventResult.ignored;
      }
      _handleBack(node.context!);
      return KeyEventResult.handled;
    }

    // Cross-zone arrow navigation — only between registered zone
    // nodes (rail ↔ sidebar ↔ content). Do NOT intercept arrows
    // when focus is inside the content area — that breaks
    // intra-screen list/grid/chip navigation.
    if (context.usesSideNav) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_handleArrowLeft()) return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_handleArrowRight()) return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// Handle Escape / Back / Gamepad-B.
  ///
  /// Focus escalation order (large-screen layouts with side nav):
  ///   content → sidebar (if registered) → rail → pop/home
  ///
  /// On compact layouts (bottom nav) or when the rail already has
  /// focus, falls through to normal pop/home navigation.
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

    // Focus escalation on large-screen layouts.
    if (context.usesSideNav && _tryEscalateFocus()) return;

    // Defer navigation to avoid "pop during build" on rapid key presses.
    Future.microtask(() {
      if (!context.mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        final location = GoRouterState.of(context).uri.path;
        if (location != AppRoutes.home) {
          context.go(AppRoutes.home);
        } else if (DeviceFormFactorService.current.isMobile ||
            DeviceFormFactorService.current.isTV) {
          // At Home with nothing to pop — show exit confirmation.
          showFocusRestoringDialog<bool>(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: Text(context.l10n.commonClose),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(context.l10n.commonCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(context.l10n.commonConfirm),
                    ),
                  ],
                ),
          ).then((confirmed) {
            if (confirmed == true) SystemNavigator.pop();
          });
        }
      }
    });
  }

  /// Attempts to escalate focus toward the navigation rail.
  ///
  /// Handles all 4 zones: D (MiniPlayer) → B.5 (SourceSelector) →
  /// B (Sidebar) → A (Rail). Returns `true` if focus was moved
  /// (caller should not pop).
  bool _tryEscalateFocus() {
    final escalation = ref.read(focusEscalationProvider);
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;

    final railNode = escalation.railNode;
    final sidebarNode = escalation.sidebarNode;
    final sourceSelectorNode = escalation.sourceSelectorNode;
    final miniPlayerNode = escalation.miniPlayerNode;

    // Already in the rail — don't escalate, let pop/home proceed.
    if (railNode != null && railNode.hasFocus) return false;

    // In MiniPlayer (Zone D) — restore prior focus.
    if (miniPlayerNode != null && miniPlayerNode.hasFocus) {
      final routePath = GoRouterState.of(context).uri.path;
      final savedKey = ref
          .read(focusRestorationProvider.notifier)
          .getKey(routePath);
      if (savedKey != null) {
        restoreFocus(ref, routePath, context);
        return true;
      }
      if (railNode != null && railNode.canRequestFocus) {
        railNode.requestFocus();
        return true;
      }
    }

    // In sidebar — escalate to rail.
    if (sidebarNode != null &&
        sidebarNode.hasFocus &&
        railNode != null &&
        railNode.canRequestFocus) {
      railNode.requestFocus();
      return true;
    }

    // In source selector (Zone B.5) — escalate to sidebar or rail.
    if (sourceSelectorNode != null && sourceSelectorNode.hasFocus) {
      if (sidebarNode != null && sidebarNode.canRequestFocus) {
        sidebarNode.requestFocus();
        return true;
      }
      if (railNode != null && railNode.canRequestFocus) {
        railNode.requestFocus();
        return true;
      }
    }

    // In content — escalate to nearest left zone.
    if (sourceSelectorNode != null && sourceSelectorNode.canRequestFocus) {
      sourceSelectorNode.requestFocus();
      return true;
    }
    if (sidebarNode != null && sidebarNode.canRequestFocus) {
      sidebarNode.requestFocus();
      return true;
    }
    if (railNode != null && railNode.canRequestFocus) {
      railNode.requestFocus();
      return true;
    }

    return false;
  }

  /// Handles D-pad Left: cross-zone navigation toward the rail.
  ///
  /// Only handles transitions between registered zone nodes
  /// (sidebar → rail, source selector → sidebar/rail). Does NOT
  /// intercept ArrowLeft from general content — that would break
  /// intra-screen horizontal navigation (genre chips, grids, etc.).
  /// Content → sidebar is handled by Escape escalation instead.
  bool _handleArrowLeft() {
    final escalation = ref.read(focusEscalationProvider);
    final railNode = escalation.railNode;
    final sidebarNode = escalation.sidebarNode;
    final sourceSelectorNode = escalation.sourceSelectorNode;

    // Already in rail — nowhere left to go.
    if (railNode != null && railNode.hasFocus) return false;

    // In sidebar — go to rail.
    if (sidebarNode != null && sidebarNode.hasFocus) {
      if (railNode != null && railNode.canRequestFocus) {
        railNode.requestFocus();
        return true;
      }
    }

    // In source selector — go to sidebar or rail.
    if (sourceSelectorNode != null && sourceSelectorNode.hasFocus) {
      if (sidebarNode != null && sidebarNode.canRequestFocus) {
        sidebarNode.requestFocus();
        return true;
      }
      if (railNode != null && railNode.canRequestFocus) {
        railNode.requestFocus();
        return true;
      }
    }

    return false;
  }

  /// Handles D-pad Right: cross-zone navigation toward content.
  ///
  /// Moves between registered zone nodes only:
  /// rail → sidebar → content (first focusable child).
  bool _handleArrowRight() {
    final escalation = ref.read(focusEscalationProvider);
    final railNode = escalation.railNode;
    final sidebarNode = escalation.sidebarNode;
    // In rail — go to sidebar (or content if no sidebar).
    if (railNode != null && railNode.hasFocus) {
      if (sidebarNode != null && sidebarNode.canRequestFocus) {
        // Focus the first traversable child inside the sidebar
        // so focus indicators show on the actual item.
        sidebarNode.requestFocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          sidebarNode.nextFocus();
        });
        return true;
      }
      // No sidebar — push focus into content via traversal.
      final primaryFocus = FocusManager.instance.primaryFocus;
      primaryFocus?.focusInDirection(TraversalDirection.right);
      return true;
    }

    // In sidebar — go to content.
    if (sidebarNode != null && sidebarNode.hasFocus) {
      final primaryFocus = FocusManager.instance.primaryFocus;
      primaryFocus?.focusInDirection(TraversalDirection.right);
      return true;
    }

    return false;
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
          onKeyEvent: _onKeyEvent,
          child: TvRemoteKeyHandler(
            onPlayPause: () {
              final player = ref.read(playerServiceProvider);
              if (player.state.isPlaying) {
                player.pause();
              } else {
                player.resume();
              }
            },
            onStop: () => ref.read(playerServiceProvider).stop(),
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
                    child: Column(
                      children: [
                        // ── FE-AS-07: Offline banner ───────────
                        OfflineBanner(
                          onReconnect:
                              () =>
                                  ref
                                      .read(playlistSyncServiceProvider)
                                      .syncAll(),
                        ),
                        // ── FE-AS-13: Breadcrumb bar ───────────
                        const BreadcrumbBar(),
                        Expanded(child: ToastOverlay(child: widget.child)),
                        const MiniPlayerBar(),
                      ],
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
class _RailNavWidget extends ConsumerStatefulWidget {
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
  ConsumerState<_RailNavWidget> createState() => _RailNavWidgetState();
}

class _RailNavWidgetState extends ConsumerState<_RailNavWidget> {
  final FocusScopeNode _railFocusScope = FocusScopeNode();
  bool _isHovering = false;
  bool _isFocused = false;
  bool get _isExtended => _isHovering || _isFocused;

  late final FocusEscalationNotifier _escalation;

  @override
  void initState() {
    super.initState();
    _escalation = ref.read(focusEscalationProvider.notifier);
    _railFocusScope.addListener(_onFocusChange);
    // Register the rail node for focus escalation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _escalation.setRailNode(_railFocusScope);
    });
  }

  @override
  void dispose() {
    _escalation.setRailNode(null);
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
