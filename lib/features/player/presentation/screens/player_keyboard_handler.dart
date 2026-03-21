import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/utils/keyboard_utils.dart';
import '../../../settings/domain/entities/remote_action.dart';
import '../../domain/entities/playback_state.dart' as app;
import '../../data/player_service.dart';
import '../providers/player_providers.dart';

/// Callback signatures for keyboard actions that need
/// screen-level state (channel zap, fullscreen, etc.).
typedef VoidAction = void Function();
typedef DirectionZap = void Function(int direction);

// ── Progressive seek acceleration state ─────────────────
LogicalKeyboardKey? _seekDirection;
int _seekRepeatCount = 0;

/// Returns multiplier for progressive seek acceleration.
///
/// 4 tiers: ≤5 repeats → 1.5x, ≤15 → 3x, ≤30 → 6x, >30 → 10x.
double getSeekMultiplier(int repeatCount) {
  if (repeatCount <= 5) return 1.5;
  if (repeatCount <= 15) return 3.0;
  if (repeatCount <= 30) return 6.0;
  return 10.0;
}

/// Handles a single [KeyEvent] from the player screen's
/// [KeyboardListener]. Returns `true` if the event was
/// consumed, `false` to let it propagate.
///
/// Stateless function — all mutable state is accessed
/// through the provided callbacks and [ref].
void handlePlayerKeyEvent({
  required KeyEvent event,
  required WidgetRef ref,
  required bool isLive,
  required bool canZap,
  required bool hasPrimaryFocus,
  required bool showZapOverlay,
  required VoidAction onPlayPause,
  required DirectionZap onZapChannel,
  required VoidAction onSeekForward,
  required VoidAction onSeekBack,
  required VoidAction onToggleFullscreen,
  required VoidAction onToggleZap,
  required VoidAction onShowZap,
  required VoidAction onBack,
  VoidAction? onToggleCaptions,
  VoidAction? onShowShortcuts,
  VoidAction? onToggleLock,
  VoidAction? onOpenGuide,
  VoidAction? onOpenSettings,
  VoidAction? onStartRecording,
  VoidAction? onOpenSearch,
  VoidAction? onShowDebug,
  VoidAction? onScreenshot,
  VoidAction? onCleanScreenshot,
  VoidAction? onAlwaysOnTop,
  VoidAction? onCycleShader,
}) {
  // Skip player shortcuts when the user is typing in a text field.
  // D-pad / arrow keys are NOT blocked — they still navigate between
  // fields. Only character and symbol keys (letters, digits, slash,
  // brackets, etc.) are suppressed so they reach the TextField.
  if (isTextFieldFocused()) {
    final key = event.logicalKey;
    // Allow navigation, activation, media, and Escape keys through
    // to the player handler even when a text field is focused.
    final isNavOrMediaKey =
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaStop ||
        key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.channelDown;
    if (!isNavOrMediaKey) return;
  }

  // Reset progressive seek on key release.
  if (event is KeyUpEvent) {
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight) {
      _seekDirection = null;
      _seekRepeatCount = 0;
    }
    return;
  }

  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

  final service = ref.read(playerServiceProvider);
  final osd = ref.read(osdStateProvider.notifier);
  final osdVisible = ref.read(osdStateProvider) != OsdState.hidden;

  final childHasFocus = osdVisible && !hasPrimaryFocus;

  // `?` (Shift+/) — shortcuts help overlay. Check before action
  // lookup so slash doesn't fire openSearch when Shift is held.
  if (event.logicalKey == LogicalKeyboardKey.slash &&
      HardwareKeyboard.instance.isShiftPressed) {
    onShowShortcuts?.call();
    return;
  }

  final settings = ref.read(settingsNotifierProvider).value;
  final keyMap = settings?.remoteKeyMap ?? defaultRemoteKeyMap;
  final action = keyMap[event.logicalKey.keyId];

  // When a child OSD button has focus, let activation and arrow
  // keys propagate so Flutter's focus system handles D-pad
  // navigation between OSD buttons naturally. Only non-navigation
  // mapped keys (K, J, L, etc.) still execute their actions.
  if (childHasFocus) {
    final k = event.logicalKey;
    final isActivationKey =
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.gameButtonA;
    final isArrowKey =
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight;
    if (isActivationKey || isArrowKey) {
      osd.show();
      return;
    }
  }

  switch (action) {
    case RemoteAction.playPause:
      onPlayPause();
      osd.show();
    case RemoteAction.channelUp:
      if (canZap) {
        onZapChannel(-1);
      } else {
        service.setVolume(service.state.volume + 0.1);
      }
      osd.show();
    case RemoteAction.channelDown:
      if (canZap) {
        onZapChannel(1);
      } else {
        service.setVolume(service.state.volume - 0.1);
      }
      osd.show();
    case RemoteAction.volumeUp:
      service.setVolume(service.state.volume + 0.1);
      osd.show();
    case RemoteAction.volumeDown:
      service.setVolume(service.state.volume - 0.1);
      osd.show();
    case RemoteAction.seekForward:
      if (isLive && canZap && !osdVisible) {
        onShowZap();
      } else if (!isLive) {
        _progressiveSeek(event, service, ref, LogicalKeyboardKey.arrowRight);
        onSeekForward();
      }
      osd.show();
    case RemoteAction.seekBack:
      if (!isLive) {
        _progressiveSeek(event, service, ref, LogicalKeyboardKey.arrowLeft);
        onSeekBack();
      }
      osd.show();
    case RemoteAction.mute:
      service.toggleMute();
      osd.show();
    case RemoteAction.fullscreen:
      onToggleFullscreen();
      osd.show();
    case RemoteAction.toggleZap:
      if (canZap) onToggleZap();
      osd.show();
    case RemoteAction.showOsd:
      osd.show();
    case RemoteAction.toggleCaptions:
      onToggleCaptions?.call();
      osd.show();
    case RemoteAction.back:
      if (showZapOverlay) {
        onToggleZap();
      } else {
        onBack();
      }
    case RemoteAction.openGuide:
      onOpenGuide?.call();
    case RemoteAction.openSettings:
      onOpenSettings?.call();
    case RemoteAction.startRecording:
      onStartRecording?.call();
    case RemoteAction.openSearch:
      onOpenSearch?.call();
    case RemoteAction.showDebug:
      onShowDebug?.call();
      osd.show();
    case null:
      osd.show();
  }

  // ── Direct key handling (no RemoteAction mapping) ──
  final key = event.logicalKey;

  // 0-9: Percentage seek (VOD only).
  if (!isLive) {
    final digit = _digitFromKey(key);
    if (digit != null) {
      final duration = service.state.duration;
      if (duration.inMilliseconds > 0) {
        final target = duration * (digit / 10.0);
        service.seek(target);
        osd.show();
      }
      return;
    }
  }

  // Frame step (paused, VOD only).
  if (!isLive && service.state.status == app.PlaybackStatus.paused) {
    if (key == LogicalKeyboardKey.comma) {
      // Step backward ~33ms (one frame at 30fps).
      final pos = service.state.position - const Duration(milliseconds: 33);
      service.seek(pos < Duration.zero ? Duration.zero : pos);
      return;
    }
    if (key == LogicalKeyboardKey.period) {
      // Step forward ~33ms.
      service.seek(service.state.position + const Duration(milliseconds: 33));
      return;
    }
  }

  // Playback speed: < (Shift+Comma) and > (Shift+Period).
  if (!isLive) {
    if (key == LogicalKeyboardKey.less) {
      _adjustSpeed(service, -1);
      osd.show();
      return;
    }
    if (key == LogicalKeyboardKey.greater) {
      _adjustSpeed(service, 1);
      osd.show();
      return;
    }
  }

  // Backslash — reset playback speed to 1.0x (VOD only).
  if (!isLive && key == LogicalKeyboardKey.backslash) {
    service.setSpeed(1.0);
    osd.show();
    return;
  }

  // ── mpv/VLC-parity shortcuts ────────────────────────────
  // A — cycle aspect ratio (Original, 16:9, 4:3, Fill, Fit).
  if (key == LogicalKeyboardKey.keyA) {
    service.cycleAspectRatio();
    osd.show();
    return;
  }

  // V — cycle subtitle track.
  if (key == LogicalKeyboardKey.keyV) {
    _cycleSubtitleTrack(service);
    osd.show();
    return;
  }

  // [ — decrease playback speed by 0.1x (VOD only).
  if (!isLive && key == LogicalKeyboardKey.bracketLeft) {
    _adjustSpeedFine(service, -0.1);
    osd.show();
    return;
  }

  // ] — increase playback speed by 0.1x (VOD only).
  if (!isLive && key == LogicalKeyboardKey.bracketRight) {
    _adjustSpeedFine(service, 0.1);
    osd.show();
    return;
  }

  // I — show/hide stream stats overlay (codec, resolution, bitrate).
  if (key == LogicalKeyboardKey.keyI) {
    ref.read(streamStatsVisibleProvider.notifier).update((v) => !v);
    osd.show();
    return;
  }

  // L — toggle screen lock.
  if (key == LogicalKeyboardKey.keyL) {
    onToggleLock?.call();
    return;
  }

  // Ctrl+S — cycle shader preset (desktop only).
  if (key == LogicalKeyboardKey.keyS &&
      HardwareKeyboard.instance.isControlPressed) {
    onCycleShader?.call();
    osd.show();
    return;
  }

  // S — screenshot. Shift+S — clean screenshot (no subtitles).
  if (key == LogicalKeyboardKey.keyS) {
    if (HardwareKeyboard.instance.isShiftPressed) {
      onCleanScreenshot?.call();
    } else {
      onScreenshot?.call();
    }
    return;
  }

  // T — toggle always-on-top (desktop only).
  if (key == LogicalKeyboardKey.keyT) {
    onAlwaysOnTop?.call();
    osd.show();
    return;
  }
}

/// Progressive seek with acceleration on key repeat.
///
/// Base step: 0.5% of duration (clamped 500ms–15s).
/// On `KeyRepeatEvent`, multiplied by [getSeekMultiplier].
void _progressiveSeek(
  KeyEvent event,
  PlayerService service,
  WidgetRef ref,
  LogicalKeyboardKey direction,
) {
  final duration = service.state.duration;
  if (duration.inMilliseconds <= 0) return;

  // Track direction change — reset if direction changes.
  if (_seekDirection != direction) {
    _seekDirection = direction;
    _seekRepeatCount = 0;
  }

  // Increment repeat count on KeyRepeatEvent.
  if (event is KeyRepeatEvent) {
    _seekRepeatCount++;
  }

  // Base step: 0.5% of duration, clamped 500ms–15s.
  final baseStepMs =
      (duration.inMilliseconds * 0.005).clamp(500, 15000).toInt();

  // Apply progressive multiplier only on repeat events.
  final multiplier =
      event is KeyRepeatEvent ? getSeekMultiplier(_seekRepeatCount) : 1.0;
  final stepMs = (baseStepMs * multiplier).clamp(500, 60000).toInt();
  final step = Duration(milliseconds: stepMs);

  final isForward = direction == LogicalKeyboardKey.arrowRight;
  final pos = service.state.position;
  final target = isForward ? pos + step : pos - step;
  final clamped = Duration(
    milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds),
  );
  service.seek(clamped);
}

/// Maps digit keys (main row + numpad) to their numeric value.
int? _digitFromKey(LogicalKeyboardKey key) {
  final digits = {
    LogicalKeyboardKey.digit0: 0,
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad0: 0,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };
  return digits[key];
}

/// Cycles playback speed: 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0
void _adjustSpeed(dynamic service, int direction) {
  const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0];
  final current = service.state.speed;
  var idx = speeds.indexWhere((s) => s >= current);
  if (idx < 0) idx = speeds.length - 1;
  idx = (idx + direction).clamp(0, speeds.length - 1);
  service.setSpeed(speeds[idx]);
}

/// Adjusts playback speed by [delta] (e.g. ±0.1x) clamped to [0.1, 4.0].
void _adjustSpeedFine(PlayerService service, double delta) {
  final current = service.state.speed;
  final next = (current + delta).clamp(0.1, 4.0);
  // Round to one decimal to avoid floating-point drift.
  service.setSpeed(double.parse(next.toStringAsFixed(1)));
}

/// Cycles to the next subtitle track (or disables if at the end).
void _cycleSubtitleTrack(PlayerService service) {
  final state = service.state;
  final trackCount = state.subtitleTracks.length;
  if (trackCount <= 0) return;

  // selectedSubtitleTrackId is nullable: null / -1 = disabled.
  final current = state.selectedSubtitleTrackId ?? -1;
  // Cycle: -1 → 0 → 1 → … → (count-1) → -1 (disabled).
  final next = current < trackCount - 1 ? current + 1 : -1;
  service.setSubtitleTrack(next);
}
