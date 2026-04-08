import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/channel.dart';
import '../providers/channel_providers.dart';

/// Mixin providing channel preview/playback actions
/// for the channel list TV layout.
///
/// Mirrors [EpgActionsMixin] but uses [AppRoutes.tv]
/// as the host route.
mixin ChannelPreviewMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Channel? _previewedChannel;

  /// The currently previewed channel.
  Channel? get previewedChannel => _previewedChannel;

  /// Start playing [channel] in the preview area
  /// without expanding to full screen.
  ///
  /// Enters preview mode via [playerModeProvider] so
  /// [PermanentVideoLayer] positions the video at the
  /// preview rect.
  void previewChannel(Channel channel) {
    final ps = ref.read(playerServiceProvider);
    // Skip re-open if already playing the same URL.
    if (ps.currentUrl != channel.streamUrl) {
      ps.play(
        channel.streamUrl,
        isLive: true,
        channelName: channel.name,
        channelLogoUrl: channel.logoUrl,
        headers:
            channel.userAgent != null
                ? {'User-Agent': channel.userAgent!}
                : null,
      );
    }

    // Keep session provider in sync so OSD actions
    // (external player, copy URL) read the current URL.
    ref
        .read(playbackSessionProvider.notifier)
        .startPreview(
          streamUrl: channel.streamUrl,
          isLive: true,
          channelName: channel.name,
          channelLogoUrl: channel.logoUrl,
          headers:
              channel.userAgent != null
                  ? {'User-Agent': channel.userAgent!}
                  : null,
        );

    // Enter preview mode — always set mode immediately so
    // PermanentVideoLayer knows to show the video once the
    // rect arrives. ChannelVideoPreview._reportRect() fires
    // via a post-frame callback and calls updatePreviewRect().
    // The video layer hides until a valid rect is available.
    final modeState = ref.read(playerModeProvider);
    if (modeState.mode != PlayerMode.fullscreen) {
      final rect = modeState.previewRect;
      // Rect.zero is a sentinel meaning "rect not yet measured" —
      // PermanentVideoLayer hides until a valid rect arrives via
      // ChannelVideoPreview._reportRect().
      ref
          .read(playerModeProvider.notifier)
          .enterPreview(rect ?? Rect.zero, hostRoute: AppRoutes.tv);
      ref.read(playerServiceProvider).forceStateEmit();
    }

    if (_previewedChannel != channel) {
      setState(() => _previewedChannel = channel);
    }
  }

  /// Expand to fullscreen via [playerModeProvider].
  ///
  /// No Navigator.push — the video and OSD are handled
  /// by AppShell's Stack layers.
  void expandPlayer() {
    ref
        .read(playerModeProvider.notifier)
        .enterFullscreen(hostRoute: AppRoutes.tv);
    ref.read(playerServiceProvider).forceStateEmit();

    final channel = previewedChannel;
    if (channel != null) {
      final groupName = ref.read(channelListProvider).effectiveGroup;
      ref
          .read(settingsNotifierProvider.notifier)
          .setLastChannel(channel.id, groupName);
    }
  }

  /// Collapse from fullscreen back to preview.
  void collapsePlayer() {
    ref.read(playerModeProvider.notifier).exitToPreview();
    ref.read(playerServiceProvider).forceStateEmit();
  }

  /// Preview [channel] and immediately expand to fullscreen.
  void playChannelFullscreen(Channel channel) {
    previewChannel(channel);
    expandPlayer();
  }

  /// Syncs the previewed channel to the currently playing
  /// channel when exiting fullscreen back to preview.
  ///
  /// Call from the host widget's [build] method so the
  /// listener is registered with the widget lifecycle.
  void listenForChannelSync() {
    ref.listen(playerModeProvider.select((s) => s.mode), (prev, mode) {
      if (prev == PlayerMode.fullscreen &&
          (mode == PlayerMode.preview || mode == PlayerMode.background)) {
        _syncToPlayingChannel();
      }
    });
  }

  /// Updates [_previewedChannel] to match the channel that
  /// is currently playing in [playbackSessionProvider].
  void _syncToPlayingChannel() {
    final session = ref.read(playbackSessionProvider);
    final channels = session.channelList;
    if (channels == null || channels.isEmpty) return;

    final idx = session.channelIndex;
    if (idx < 0 || idx >= channels.length) return;

    final playing = channels[idx];
    if (_previewedChannel?.id != playing.id) {
      setState(() => _previewedChannel = playing);
    }
  }
}
