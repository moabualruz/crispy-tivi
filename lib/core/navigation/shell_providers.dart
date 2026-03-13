import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Focus escalation ─────────────────────────────────────────────────────────

/// Holds [FocusNode] references for back/escape focus escalation.
///
/// When the user presses Escape/Back, focus escalates through zones
/// before performing navigation:
///   content → [sourceSelectorNode] → [sidebarNode] → [railNode] → pop/home
///
/// Zone D ([miniPlayerNode]) handles Escape by restoring prior focus.
///
/// Screens with a sidebar (e.g. channel list with [GroupSidebar])
/// register their sidebar node. [AppShell] always registers the rail.
class FocusEscalationNotifier extends Notifier<FocusEscalationState> {
  @override
  FocusEscalationState build() => const FocusEscalationState();

  /// Register the main navigation rail's focus scope.
  void setRailNode(FocusScopeNode? node) =>
      state = state.copyWith(railNode: node);

  /// Register a screen-level sidebar focus node (e.g. GroupSidebar).
  /// Pass `null` when the screen is disposed.
  void setSidebarNode(FocusNode? node) =>
      state = state.copyWith(sidebarNode: node);

  /// Register the source selector bar focus node (Zone B.5).
  /// Pass `null` when the widget is disposed.
  void setSourceSelectorNode(FocusNode? node) =>
      state =
          node == null
              ? state.copyWith(clearSourceSelector: true)
              : state.copyWith(sourceSelectorNode: node);

  /// Register the mini player bar focus node (Zone D).
  /// Pass `null` when the widget is disposed.
  void setMiniPlayerNode(FocusNode? node) =>
      state =
          node == null
              ? state.copyWith(clearMiniPlayer: true)
              : state.copyWith(miniPlayerNode: node);
}

/// Immutable state for [FocusEscalationNotifier].
class FocusEscalationState {
  const FocusEscalationState({
    this.railNode,
    this.sidebarNode,
    this.sourceSelectorNode,
    this.miniPlayerNode,
  });

  /// The navigation rail's [FocusScopeNode].
  final FocusScopeNode? railNode;

  /// The current screen's sidebar [FocusNode] (if any).
  final FocusNode? sidebarNode;

  /// The source selector bar [FocusNode] (Zone B.5, if visible).
  final FocusNode? sourceSelectorNode;

  /// The mini player bar [FocusNode] (Zone D, if visible).
  final FocusNode? miniPlayerNode;

  /// Creates a copy with the given fields replaced.
  FocusEscalationState copyWith({
    FocusScopeNode? railNode,
    FocusNode? sidebarNode,
    bool clearSidebar = false,
    FocusNode? sourceSelectorNode,
    bool clearSourceSelector = false,
    FocusNode? miniPlayerNode,
    bool clearMiniPlayer = false,
  }) => FocusEscalationState(
    railNode: railNode ?? this.railNode,
    sidebarNode: clearSidebar ? null : (sidebarNode ?? this.sidebarNode),
    sourceSelectorNode:
        clearSourceSelector
            ? null
            : (sourceSelectorNode ?? this.sourceSelectorNode),
    miniPlayerNode:
        clearMiniPlayer ? null : (miniPlayerNode ?? this.miniPlayerNode),
  );
}

/// Provider for focus escalation state.
final focusEscalationProvider =
    NotifierProvider<FocusEscalationNotifier, FocusEscalationState>(
      FocusEscalationNotifier.new,
    );

// ── Global loading indicator ──────────────────────────────────────────────────

/// Global loading indicator notifier.
///
/// When state is `true`, [AppShell] shows a thin [LinearProgressIndicator]
/// at the top of the screen. Feature providers can set this to communicate
/// long-running background work to the user.
///
/// Example:
/// ```dart
/// ref.read(globalLoadingProvider.notifier).setLoading(true);
/// await doSomethingAsync();
/// ref.read(globalLoadingProvider.notifier).setLoading(false);
/// ```
final globalLoadingProvider = NotifierProvider<GlobalLoadingNotifier, bool>(
  GlobalLoadingNotifier.new,
);

/// Controls the global loading indicator state.
class GlobalLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Sets the global loading state.
  void setLoading(bool value) => state = value;
}
