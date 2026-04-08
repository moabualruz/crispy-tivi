import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/pip_impl.dart';

/// Picture-in-Picture state for a single video slot.
class PipState {
  const PipState({this.isActive = false, this.slotIndex});

  /// Whether PiP is currently active.
  final bool isActive;

  /// The multiview slot index that is in PiP, or null for
  /// single-player PiP.
  final int? slotIndex;

  PipState copyWith({bool? isActive, int? slotIndex}) {
    return PipState(
      isActive: isActive ?? this.isActive,
      slotIndex: slotIndex ?? this.slotIndex,
    );
  }
}

/// Unified Picture-in-Picture controller for all 6 platforms.
///
/// Replaces the old `PipHandler` singleton. All PiP state
/// flows through this single Riverpod provider.
///
/// ## Platform support
/// - **Android**: Native `PictureInPictureParams` via
///   MethodChannel.
/// - **iOS**: `AVPictureInPictureController` via IosPipPlayer
///   handoff.
/// - **Windows/macOS/Linux**: `window_manager` resize.
/// - **Web**: Browser `requestPictureInPicture` API.
class PipNotifier extends Notifier<PipState> {
  final _impl = PipImpl();

  @override
  PipState build() {
    _impl.onNativePipChanged = _onNativePipChanged;
    return const PipState();
  }

  /// Whether PiP is supported on the current platform.
  bool get isSupported {
    if (kIsWeb) return _impl.isSupported;
    return _impl.isSupported;
  }

  /// Attempt to enter Picture-in-Picture mode.
  ///
  /// Returns `(true, null)` on success, or
  /// `(false, errorMessage)` on failure.
  Future<(bool, String?)> enterPip({
    int? slotIndex,
    int? width,
    int? height,
  }) async {
    if (!isSupported) return (false, 'PiP not supported');

    final (success, error) = await _impl.enterPiP(width: width, height: height);
    if (success) {
      state = state.copyWith(isActive: true, slotIndex: slotIndex);
    }
    return (success, error);
  }

  /// Exit Picture-in-Picture mode and restore normal UI.
  Future<void> exitPip() async {
    if (!state.isActive) return;
    await _impl.exitPiP();
    state = const PipState();
  }

  /// Toggle PiP mode.
  Future<(bool, String?)> togglePip({
    int? slotIndex,
    int? width,
    int? height,
  }) async {
    if (state.isActive) {
      await exitPip();
      return (true, null);
    }
    return enterPip(slotIndex: slotIndex, width: width, height: height);
  }

  /// Arm/disarm native auto-PiP for background entry.
  Future<void> setAutoPipReady({
    required bool ready,
    int? width,
    int? height,
  }) async {
    await _impl.setAutoPipReady(ready: ready, width: width, height: height);
  }

  /// Called by the native layer (via MethodChannel callback)
  /// when PiP mode changes externally (e.g. user dismisses
  /// the PiP window on Android).
  void onNativePipChanged({required bool isInPip}) {
    if (isInPip) {
      state = state.copyWith(isActive: true);
    } else {
      state = const PipState();
    }
  }

  void _onNativePipChanged(bool isInPip) {
    onNativePipChanged(isInPip: isInPip);
  }
}

/// Global PiP provider.
final pipProvider = NotifierProvider<PipNotifier, PipState>(PipNotifier.new);
