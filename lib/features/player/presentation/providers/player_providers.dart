import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/player_service.dart';
import '../../domain/entities/playback_state.dart';

export 'cursor_providers.dart';
export 'osd_providers.dart';
export 'playback_session_provider.dart';
export 'player_mode_provider.dart';
export 'player_settings_providers.dart';

/// Global [PlayerService] provider — single instance.
final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provides the raw [Player] for the Video widget.
final playerProvider = Provider<Player>((ref) {
  return ref.watch(playerServiceProvider).player;
});

/// Stream-based provider of [PlaybackState] snapshots.
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final service = ref.watch(playerServiceProvider);
  return service.stateStream;
});

// ─────────────────────────────────────────────────────────────
//  Playback Selectors — surgical rebuild providers
// ─────────────────────────────────────────────────────────────

/// Derived provider: playback status only.
/// Rebuilds only when status changes (not on position/
/// volume updates). Requires PlaybackState == (BUG-17).
final playbackStatusProvider = Provider<PlaybackStatus>((ref) {
  return ref.watch(
    playbackStateProvider.select((s) => s.value?.status ?? PlaybackStatus.idle),
  );
});

/// Derived provider: playback position only.
/// Updates at ~4 Hz (throttled by PlayerServiceBase).
final playbackPositionProvider = Provider<Duration>((ref) {
  return ref.watch(
    playbackStateProvider.select((s) => s.value?.position ?? Duration.zero),
  );
});

/// Derived provider: volume only.
final playbackVolumeProvider = Provider<double>((ref) {
  return ref.watch(playbackStateProvider.select((s) => s.value?.volume ?? 1.0));
});
