import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../iptv/domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../providers/player_providers.dart';
import 'lock_indicator.dart';
import 'movie_completion_overlay.dart';
import 'next_episode_overlay.dart';
import 'still_watching_overlay.dart';
import 'player_indicators.dart';
import 'pip_overlay.dart';
import 'player_osd_builder.dart';
import 'player_gesture_overlays.dart';
import 'player_queue_overlay.dart';
import 'screenshot_indicator.dart';
import 'skip_segment_button.dart';

/// Builds the layered [Stack] of video surface +
/// overlays for the player screen.
///
/// All mutable state is passed in via constructor
/// parameters. Lock state is read directly from
/// [playerLockedProvider].
class PlayerStack extends ConsumerWidget {
  const PlayerStack({
    required this.videoSurface,
    required this.brightnessNotifier,
    required this.isInPip,
    required this.isBuffering,
    required this.retryCount,
    required this.seekDirection,
    required this.hasError,
    required this.errorMessage,
    required this.onRetry,
    required this.isSwiping,
    required this.swipeType,
    required this.swipeValue,
    required this.zapChannelName,
    required this.canZap,
    required this.showZapOverlay,
    required this.rightEdgeThreshold,
    required this.onSwipeLeftEdge,
    required this.isLive,
    required this.channelList,
    required this.currentChannelIndex,
    required this.onZapDismiss,
    required this.onChannelSelected,
    required this.nextEpisode,
    required this.onPlayNext,
    required this.onCancelNext,
    required this.stillWatchingCount,
    required this.onStillWatchingContinue,
    required this.onStillWatchingDone,
    required this.showMovieCompletion,
    required this.currentTitle,
    required this.onWatchAgain,
    required this.onBrowseMore,
    required this.streamUrl,
    required this.onBack,
    required this.onToggleFullscreen,
    required this.onEnterPip,
    required this.onToggleZapOverlay,
    required this.onOpenExternal,
    required this.onSkipToQueueItem,
    this.channelLogoUrl,
    this.seekStepSeconds = 10,
    super.key,
  });

  final Widget videoSurface;
  final ValueNotifier<double> brightnessNotifier;
  final bool isInPip;
  final bool isBuffering;
  final int retryCount;
  final SeekDirection? seekDirection;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback onRetry;
  final bool isSwiping;
  final SwipeType? swipeType;
  final double swipeValue;
  final String? zapChannelName;
  final bool canZap;
  final bool showZapOverlay;
  final double rightEdgeThreshold;
  final VoidCallback onSwipeLeftEdge;
  final bool isLive;
  final List<Channel>? channelList;
  final int currentChannelIndex;
  final VoidCallback onZapDismiss;
  final void Function(Channel) onChannelSelected;
  final VodItem? nextEpisode;
  final VoidCallback? onPlayNext;
  final VoidCallback? onCancelNext;

  /// Non-zero when "Still Watching?" prompt should show.
  final int stillWatchingCount;
  final VoidCallback? onStillWatchingContinue;
  final VoidCallback? onStillWatchingDone;
  final bool showMovieCompletion;
  final String? currentTitle;
  final VoidCallback? onWatchAgain;
  final VoidCallback? onBrowseMore;
  final String streamUrl;
  final VoidCallback onBack;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onEnterPip;
  final VoidCallback? onToggleZapOverlay;
  final VoidCallback? onOpenExternal;

  /// Called when the user taps a queue item to skip to it.
  final ValueChanged<QueueItem> onSkipToQueueItem;

  /// Optional channel logo URL forwarded to [BufferingIndicator].
  final String? channelLogoUrl;

  /// Seek step in seconds forwarded to [SeekIndicator].
  final int seekStepSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = ref.watch(playerLockedProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        videoSurface,
        BrightnessOverlay(
          brightnessNotifier: brightnessNotifier,
          isInPip: isInPip,
        ),
        BufferingIndicator(
          isBuffering: isBuffering,
          retryCount: retryCount,
          isInPip: isInPip,
          channelName: currentTitle,
          channelLogoUrl: channelLogoUrl,
        ),
        SeekIndicator(
          direction: seekDirection,
          isInPip: isInPip,
          seekStepSeconds: seekStepSeconds,
        ),
        ErrorOverlay(
          hasError: hasError,
          errorMessage: errorMessage,
          isInPip: isInPip,
          onRetry: onRetry,
        ),
        GestureRingOverlay(
          isSwiping: isSwiping,
          swipeType: swipeType,
          value: swipeValue,
          isInPip: isInPip,
        ),
        ZapNameOverlay(channelName: zapChannelName, isInPip: isInPip),
        if (canZap && !isInPip && !showZapOverlay)
          RightEdgeZapZone(
            edgeThreshold: rightEdgeThreshold,
            onSwipeLeft: onSwipeLeftEdge,
          ),
        // NOTE: ChannelZapOverlay is rendered OUTSIDE this Stack
        // (as a sibling above the GestureDetector in the parent
        // player_fullscreen_overlay.dart) so it can receive tap
        // events without the GestureDetector intercepting them.
        if (nextEpisode != null && !isInPip)
          NextEpisodeOverlay(
            nextEpisode: nextEpisode!,
            onPlayNext: onPlayNext ?? () {},
            onCancel: onCancelNext ?? () {},
          ),
        if (stillWatchingCount > 0 && !isInPip)
          StillWatchingOverlay(
            episodeCount: stillWatchingCount,
            onContinue: onStillWatchingContinue ?? () {},
            onDone: onStillWatchingDone ?? () {},
          ),
        if (showMovieCompletion && !isInPip)
          MovieCompletionOverlay(
            currentTitle: currentTitle ?? '',
            onWatchAgain: onWatchAgain ?? () {},
            onBrowseMore: onBrowseMore ?? () {},
          ),
        // Skip segment button (intro / recap / credits).
        // Only shown during VOD playback when a segment
        // is active; hidden for live streams.
        // FE-PS-03: gated by showSkipButtonsProvider setting.
        if (!isInPip && !isLive && ref.watch(showSkipButtonsProvider))
          const SkipSegmentButton(),

        if (!isInPip)
          RepaintBoundary(
            child: PlayerOsdBuilder(
              streamUrl: streamUrl,
              isLive: isLive,
              channelList: channelList,
              currentChannelIndex: currentChannelIndex,
              onBack: onBack,
              onToggleFullscreen: onToggleFullscreen,
              onEnterPip: onEnterPip,
              onToggleZapOverlay: onToggleZapOverlay,
              onOpenExternal: onOpenExternal,
            ),
          ),

        // Queue panel (slides in from right).
        if (!isInPip) PlayerQueueOverlay(onSkipTo: onSkipToQueueItem),

        // Screenshot flash + result indicator.
        if (!isInPip) const ScreenshotIndicator(),

        // Desktop PiP hover controls: restore, close, play/pause.
        if (isInPip) const PipOverlay(),

        // Touch lock indicator — topmost overlay, absorbs
        // all gestures when active.
        if (!isInPip && isLocked)
          LockIndicator(
            onUnlockAttempt: () {
              ref.read(playerLockedProvider.notifier).setLocked(value: false);
            },
          ),
      ],
    );
  }
}
