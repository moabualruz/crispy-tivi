import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';

/// Seeks the player by [delta] relative to the current position.
///
/// Clamps backwards seeks to [Duration.zero] so playback never
/// goes before the start of the stream.
///
/// Shared by [PlayerOsd] center controls, [PlayerGestureMixin]
/// double-tap, and keyboard shortcuts to avoid duplicating the
/// position-read + seek pattern (PS-13).
void seekRelative(WidgetRef ref, Duration delta) {
  final service = ref.read(playerServiceProvider);
  final currentPos =
      ref.read(playbackStateProvider).value?.position ?? Duration.zero;
  final target = currentPos + delta;
  service.seek(target < Duration.zero ? Duration.zero : target);
}
