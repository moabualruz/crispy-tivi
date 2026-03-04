import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../settings/domain/entities/remote_action.dart';
import '../../domain/entities/playback_state.dart' as app;
import '../../data/player_service.dart';
import '../providers/player_providers.dart';

/// Callback signatures for keyboard actions that need
/// screen-level state (channel zap, fullscreen, etc.).
typedef VoidAction = void Function();
typedef DirectionZap = void Function(int direction);

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
}) {
  if (event is! KeyDownEvent) return;

  final service = ref.read(playerServiceProvider);
  final osd = ref.read(osdStateProvider.notifier);
  final osdVisible = ref.read(osdStateProvider) != OsdState.hidden;

  final childHasFocus = osdVisible && !hasPrimaryFocus;

  final settings = ref.read(settingsNotifierProvider).value;
  final keyMap = settings?.remoteKeyMap ?? defaultRemoteKeyMap;
  final action = keyMap[event.logicalKey.keyId];

  // When a child OSD button has focus, let activation keys
  // (Enter/Space/Select/GamepadA) propagate to the button
  // instead of triggering play/pause. Other mapped keys (K,
  // arrow-based actions, etc.) still execute normally.
  if (childHasFocus) {
    final isActivationKey =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;
    if (isActivationKey) {
      osd.show();
      return;
    }
  }

  switch (action) {
    case RemoteAction.playPause:
      service.playOrPause();
      osd.show();
    case RemoteAction.channelUp:
      if (canZap) {
        onZapChannel(-1);
      } else {
        service.setVolume((service.state.volume + 0.1).clamp(0.0, 1.0));
      }
      osd.show();
    case RemoteAction.channelDown:
      if (canZap) {
        onZapChannel(1);
      } else {
        service.setVolume((service.state.volume - 0.1).clamp(0.0, 1.0));
      }
      osd.show();
    case RemoteAction.volumeUp:
      service.setVolume((service.state.volume + 0.1).clamp(0.0, 1.0));
      osd.show();
    case RemoteAction.volumeDown:
      service.setVolume((service.state.volume - 0.1).clamp(0.0, 1.0));
      osd.show();
    case RemoteAction.seekForward:
      if (isLive && canZap && !osdVisible) {
        onShowZap();
      } else if (!isLive) {
        onSeekForward();
      }
      osd.show();
    case RemoteAction.seekBack:
      if (!isLive) {
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
    case null:
      osd.show();
  }

  // ── Direct key handling (no RemoteAction mapping) ──
  final key = event.logicalKey;

  // `?` (Shift+/) — shortcuts help overlay.
  if (key == LogicalKeyboardKey.slash &&
      HardwareKeyboard.instance.isShiftPressed) {
    onShowShortcuts?.call();
    return;
  }

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

  // M — toggle mute.
  if (key == LogicalKeyboardKey.keyM) {
    service.toggleMute();
    osd.show();
    return;
  }

  // F — toggle fullscreen.
  if (key == LogicalKeyboardKey.keyF) {
    onToggleFullscreen();
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
}

/// Maps digit keys to their numeric value.
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
