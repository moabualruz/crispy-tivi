import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/toggle_notifier.dart';

// ─────────────────────────────────────────────────────────────
//  Mouse cursor auto-hide
// ─────────────────────────────────────────────────────────────

/// Whether the mouse cursor should be visible.
final mouseCursorVisibleProvider = NotifierProvider<MouseCursorNotifier, bool>(
  MouseCursorNotifier.new,
);

class MouseCursorNotifier extends Notifier<bool> {
  Timer? _hideTimer;
  static const _hideDuration = Duration(seconds: 3);

  @override
  bool build() {
    ref.onDispose(() => _hideTimer?.cancel());
    return true;
  }

  /// Called on any mouse movement — shows cursor and resets timer.
  void onMouseMove() {
    if (!state) state = true;
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDuration, () {
      state = false;
    });
  }
}

// ─────────────────────────────────────────────────────────────
//  Stream Stats (Nerd Stats)
// ─────────────────────────────────────────────────────────────

/// Whether the Stream Stats (Nerd Stats) overlay is visible.
final streamStatsVisibleProvider = NotifierProvider<StreamStatsNotifier, bool>(
  StreamStatsNotifier.new,
);

class StreamStatsNotifier extends ToggleNotifier {
  void update(bool Function(bool) cb) {
    state = cb(state);
  }
}
