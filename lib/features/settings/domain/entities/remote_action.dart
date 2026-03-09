import 'package:flutter/services.dart';

/// Actions that can be assigned to remote/keyboard keys.
enum RemoteAction {
  /// Toggle play / pause.
  playPause('Play / Pause'),

  /// Switch to previous channel (live TV).
  channelUp('Channel Up'),

  /// Switch to next channel (live TV).
  channelDown('Channel Down'),

  /// Increase volume.
  volumeUp('Volume Up'),

  /// Decrease volume.
  volumeDown('Volume Down'),

  /// Seek forward 10 seconds (VOD).
  seekForward('Seek Forward'),

  /// Seek backward 10 seconds (VOD).
  seekBack('Seek Back'),

  /// Toggle mute.
  mute('Mute'),

  /// Toggle fullscreen mode.
  fullscreen('Fullscreen'),

  /// Navigate back / close overlay.
  back('Back'),

  /// Toggle channel zap overlay (live TV).
  toggleZap('Zap Overlay'),

  /// Show OSD / controls.
  showOsd('Show Controls'),

  /// Toggle subtitle track.
  toggleCaptions('Toggle Captions'),

  /// Navigate to the EPG guide screen.
  openGuide('Open Guide'),

  /// Navigate to the settings screen.
  openSettings('Open Settings'),

  /// Start/stop DVR recording for the current channel.
  startRecording('Start Recording'),

  /// Open the search screen.
  openSearch('Open Search'),

  /// Toggle the stream debug/diagnostics overlay.
  showDebug('Show Debug');

  const RemoteAction(this.label);

  /// Human-readable label for the settings UI.
  final String label;
}

/// Default key-to-action mappings.
///
/// Keys are [LogicalKeyboardKey.keyId] values.
/// Includes keyboard, remote control, and gamepad buttons.
final Map<int, RemoteAction> defaultRemoteKeyMap = Map.unmodifiable({
  // ── Keyboard / remote ──────────────────────────────
  LogicalKeyboardKey.space.keyId: RemoteAction.playPause,
  LogicalKeyboardKey.select.keyId: RemoteAction.playPause,
  LogicalKeyboardKey.enter.keyId: RemoteAction.playPause,
  LogicalKeyboardKey.arrowUp.keyId: RemoteAction.channelUp,
  LogicalKeyboardKey.arrowDown.keyId: RemoteAction.channelDown,
  LogicalKeyboardKey.arrowLeft.keyId: RemoteAction.seekBack,
  LogicalKeyboardKey.arrowRight.keyId: RemoteAction.seekForward,
  LogicalKeyboardKey.keyM.keyId: RemoteAction.mute,
  LogicalKeyboardKey.keyF.keyId: RemoteAction.fullscreen,
  LogicalKeyboardKey.keyZ.keyId: RemoteAction.toggleZap,
  LogicalKeyboardKey.escape.keyId: RemoteAction.back,
  LogicalKeyboardKey.goBack.keyId: RemoteAction.back,

  LogicalKeyboardKey.keyK.keyId: RemoteAction.playPause,
  LogicalKeyboardKey.keyJ.keyId: RemoteAction.seekBack,
  LogicalKeyboardKey.keyL.keyId: RemoteAction.seekForward,
  LogicalKeyboardKey.keyC.keyId: RemoteAction.toggleCaptions,

  // ── Quick-access shortcuts ─────────────────────────
  LogicalKeyboardKey.keyR.keyId: RemoteAction.startRecording,
  LogicalKeyboardKey.keyG.keyId: RemoteAction.openGuide,
  LogicalKeyboardKey.keyS.keyId: RemoteAction.openSettings,
  LogicalKeyboardKey.keyD.keyId: RemoteAction.showDebug,
  LogicalKeyboardKey.slash.keyId: RemoteAction.openSearch,

  // ── Media keys (TV remotes) ──────────────────────────
  LogicalKeyboardKey.mediaRewind.keyId: RemoteAction.seekBack,
  LogicalKeyboardKey.mediaFastForward.keyId: RemoteAction.seekForward,
  LogicalKeyboardKey.mediaPlayPause.keyId: RemoteAction.playPause,
  LogicalKeyboardKey.mediaPlay.keyId: RemoteAction.playPause,
  LogicalKeyboardKey.mediaPause.keyId: RemoteAction.playPause,
  LogicalKeyboardKey.contextMenu.keyId: RemoteAction.showOsd,

  // ── Gamepad buttons ────────────────────────────────
  // A → Play/Pause (select in player context)
  LogicalKeyboardKey.gameButtonA.keyId: RemoteAction.playPause,
  // B → Back / Cancel
  LogicalKeyboardKey.gameButtonB.keyId: RemoteAction.back,
  // X → Toggle zap overlay (context menu)
  LogicalKeyboardKey.gameButtonX.keyId: RemoteAction.toggleZap,
  // Y → Show OSD / controls
  LogicalKeyboardKey.gameButtonY.keyId: RemoteAction.showOsd,
  // Left bumper → Seek back
  LogicalKeyboardKey.gameButtonLeft1.keyId: RemoteAction.seekBack,
  // Right bumper → Seek forward
  LogicalKeyboardKey.gameButtonRight1.keyId: RemoteAction.seekForward,
  // Left trigger → Volume down
  LogicalKeyboardKey.gameButtonLeft2.keyId: RemoteAction.volumeDown,
  // Right trigger → Volume up
  LogicalKeyboardKey.gameButtonRight2.keyId: RemoteAction.volumeUp,
  // Start → Fullscreen
  LogicalKeyboardKey.gameButtonStart.keyId: RemoteAction.fullscreen,
  // Select → Mute
  LogicalKeyboardKey.gameButtonSelect.keyId: RemoteAction.mute,
});

/// Returns human-readable label for a key ID.
String keyLabel(int keyId) {
  final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
  if (key == null) return 'Key $keyId';
  return key.keyLabel.isNotEmpty ? key.keyLabel : key.debugName ?? 'Key $keyId';
}

/// Serializes a key map to JSON-safe format.
Map<String, String> serializeKeyMap(Map<int, RemoteAction> map) {
  return map.map((k, v) => MapEntry(k.toString(), v.name));
}

/// Deserializes from JSON-safe format.
Map<int, RemoteAction> deserializeKeyMap(Map<String, String> json) {
  final result = <int, RemoteAction>{};
  for (final entry in json.entries) {
    final keyId = int.tryParse(entry.key);
    if (keyId == null) continue;
    try {
      result[keyId] = RemoteAction.values.byName(entry.value);
    } on ArgumentError catch (_) {
      // Skip unknown action names (forward compat).
    }
  }
  return result;
}
