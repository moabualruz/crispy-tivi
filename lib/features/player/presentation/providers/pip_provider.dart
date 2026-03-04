import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Controls Picture-in-Picture mode for the video player.
///
/// ## Platform support
/// - **Android**: uses `PictureInPictureParams` via a MethodChannel.
///   Requires `android:supportsPictureInPicture="true"` in the Activity
///   manifest and `onPictureInPictureModeChanged` forwarded to Flutter.
/// - **iOS**: uses `AVPictureInPictureController`.
/// - **Other platforms**: PiP is not available — [isPlatformSupported]
///   returns false and [enterPip] is a no-op.
class PipNotifier extends Notifier<PipState> {
  // Platform channel shared with native Android/iOS PiP implementation.
  //
  // Channel name must match the native side registration.
  // Methods: `enterPip`, `exitPip`.
  static const _channel = MethodChannel('crispy/pip');

  @override
  PipState build() => const PipState();

  /// Whether the current platform supports PiP.
  ///
  /// Returns true only on Android and iOS.
  static bool get isPlatformSupported => Platform.isAndroid || Platform.isIOS;

  /// Attempt to enter Picture-in-Picture mode for [slotIndex].
  ///
  /// On Android, this invokes `PictureInPictureParams.Builder`
  /// to set the aspect ratio and calls
  /// `Activity.enterPictureInPictureMode()`.
  ///
  /// On iOS, this activates `AVPictureInPictureController.startPictureInPicture()`.
  Future<void> enterPip({int? slotIndex}) async {
    if (!isPlatformSupported) return;

    try {
      await _channel.invokeMethod<void>('enterPip', {
        'slotIndex': slotIndex ?? 0,
      });
      state = state.copyWith(isActive: true, slotIndex: slotIndex);
    } on PlatformException {
      // PiP request silently fails if the platform denies it
      // (e.g., user disabled PiP for the app in system settings).
    }
  }

  /// Exit Picture-in-Picture mode and restore normal playback.
  Future<void> exitPip() async {
    if (!state.isActive) return;

    try {
      await _channel.invokeMethod<void>('exitPip');
    } on PlatformException {
      // Ignored — state is cleared regardless.
    }

    state = const PipState();
  }

  /// Called by the native layer (via MethodChannel callback) when
  /// PiP mode changes externally (e.g. user dismisses the PiP window).
  void onNativePipChanged({required bool isInPip}) {
    state = state.copyWith(isActive: isInPip);
  }
}

/// Global PiP provider.
final pipProvider = NotifierProvider<PipNotifier, PipState>(PipNotifier.new);
