import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../favorites/data/favorites_history_service.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../providers/player_providers.dart';
import 'player_fullscreen_overlay.dart';
import 'player_history_tracker.dart';
import 'player_queue_overlay.dart';

/// Channel-zapping, active-stream tracking, and queue-item playback
/// for [PlayerFullscreenOverlay].
///
/// Applied after [PlayerHistoryMixin] so [playNextEpisode] resolves.
mixin PlayerFullscreenZapMixin
    on ConsumerState<PlayerFullscreenOverlay>, PlayerHistoryMixin {
  // ── Zap state ──
  String? zapChannelName;
  Timer? zapOverlayTimer;
  bool showZapOverlay = false;

  // ── Session tracking ──
  String? activeStreamUrl;

  // ────────────────────────────────────────────────
  //  Channel zapping
  // ────────────────────────────────────────────────

  /// Zap to the channel [direction] steps away in the current list.
  ///
  /// Positive [direction] = next channel, negative = previous.
  void zapChannel(int direction) {
    final session = ref.read(playbackSessionProvider);
    final channels = session.channelList;
    if (channels == null || channels.length <= 1) return;

    final idx = (session.channelIndex + direction) % channels.length;
    _zapToChannelAt(channels[idx], index: idx);
  }

  /// Zap directly to [ch] by resolving its index from the session list.
  void zapToChannel(Channel ch) {
    final channels = ref.read(playbackSessionProvider).channelList;
    final idx = channels?.indexWhere((c) => c.id == ch.id) ?? -1;
    _zapToChannelAt(ch, index: idx >= 0 ? idx : null);
  }

  /// Core zap implementation — plays [ch], updates session index if
  /// [index] is provided, and shows the brief channel-name overlay.
  void _zapToChannelAt(Channel ch, {int? index}) {
    if (index != null) {
      ref.read(playbackSessionProvider.notifier).updateChannelIndex(index);
    }

    ref
        .read(playerServiceProvider)
        .play(
          ch.streamUrl,
          isLive: true,
          channelName: ch.name,
          channelLogoUrl: ch.logoUrl,
          headers: ch.userAgent != null ? {'User-Agent': ch.userAgent!} : null,
        );

    activeStreamUrl = ch.streamUrl;
    _showZapNameBriefly(ch.name);
    ref.read(favoritesHistoryProvider.notifier).addToHistory(ch);
  }

  void _showZapNameBriefly(String name) {
    zapOverlayTimer?.cancel();
    setState(() => zapChannelName = name);
    zapOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => zapChannelName = null);
    });
  }

  // ────────────────────────────────────────────────
  //  Queue item playback
  // ────────────────────────────────────────────────

  /// Plays a queue item based on the current session type.
  void playQueueItem(QueueItem item, PlaybackSessionState session) {
    ref.read(queueProvider.notifier).hide();

    if (session.isLive) {
      final ch = session.channelList?.firstWhere(
        (c) => c.id == item.id,
        orElse:
            () => Channel(
              id: item.id,
              name: item.title,
              streamUrl: item.streamUrl,
            ),
      );
      if (ch != null) zapToChannel(ch);
    } else {
      final ep = session.episodeList?.firstWhere(
        (e) => e.id == item.id,
        orElse:
            () => VodItem(
              id: item.id,
              name: item.title,
              streamUrl: item.streamUrl,
              type: VodType.episode,
            ),
      );
      if (ep != null) playNextEpisode(ep);
    }
  }
}
