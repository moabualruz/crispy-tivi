import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/utils/input_mode_notifier.dart';
import '../../domain/entities/playback_state.dart';
import '../providers/player_providers.dart';
import '../widgets/stream_stats_overlay.dart';
import '../widgets/subtitle_position_manager.dart';
import 'player_osd/osd_shared.dart';
import 'player_osd/subtitle_style_dialog.dart';
import 'screenshot_indicator.dart';
import 'player_osd/osd_audio_picker.dart';
import 'player_osd/osd_bottom_bar.dart';
import 'player_osd/osd_center_controls.dart';
import 'player_osd/osd_speed_picker.dart';
import 'player_osd/osd_subtitle_picker.dart';
import 'player_osd/osd_top_bar.dart';
import 'player_seek_utils.dart';

/// On-screen display overlay.
///
/// Layout: top gradient bar (back + title), center
/// controls (skip back / play-pause / skip forward),
/// bottom gradient bar (left: play + volume + title,
/// right: subs + speed + fullscreen), brand red
/// progress bar above bottom bar.
///
/// Auto-hides after 4 seconds of inactivity.
class PlayerOsd extends ConsumerStatefulWidget {
  const PlayerOsd({
    this.state,
    this.streamUrl,
    this.channelEpgId,
    this.onBack,
    this.onFavorite,
    this.onEnterPip,
    this.onSleepTimer,
    this.onToggleFullscreen,
    this.onSearch,
    this.onChannelList,
    this.onRecordings,
    this.onOpenExternal,
    this.onCopyUrl,
    this.isFavorite = false,
    super.key,
  });

  /// Optional playback state. When `null`, the OSD
  /// watches [playbackStateProvider] directly.
  final PlaybackState? state;
  final String? streamUrl;
  final String? channelEpgId;
  final VoidCallback? onBack;
  final VoidCallback? onFavorite;
  final VoidCallback? onEnterPip;
  final VoidCallback? onSleepTimer;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onSearch;
  final VoidCallback? onChannelList;
  final VoidCallback? onRecordings;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onCopyUrl;
  final bool isFavorite;

  @override
  ConsumerState<PlayerOsd> createState() => _PlayerOsdState();
}

class _PlayerOsdState extends ConsumerState<PlayerOsd> {
  SubtitlePositionManager? _subPosManager;

  @override
  void dispose() {
    _subPosManager?.dispose();
    super.dispose();
  }

  // ── Screenshot ──────────────────────────────────

  /// Captures the current video frame and saves to disk.
  Future<void> _captureScreenshot() async {
    await captureScreenshot(boundaryKey: screenshotBoundaryKey, ref: ref);
  }

  @override
  Widget build(BuildContext context) {
    final osdState = ref.watch(osdStateProvider);
    final inputMode = ref.watch(inputModeProvider);
    // Build full OSD content during visible and
    // fading states (fading needs content for the
    // fade-out animation). Skip during hidden to
    // avoid expensive EPG/thumbnail provider watches
    // that would fire on every position stream
    // update (~60 times/sec).
    final showContent = osdState != OsdState.hidden;

    // Sync pause state to OSD timer.
    ref.listen(
      playbackStateProvider.select((s) => s.value?.isPlaying ?? false),
      (prev, isPlaying) {
        if (!mounted) return;
        ref.read(osdStateProvider.notifier).onPlaybackStateChanged(isPlaying);
      },
    );

    // Sync input mode to OSD timeout.
    ref.watch(osdTimeoutSyncProvider);

    // ── Subtitle position sync ──
    // Shift subtitles up when OSD is visible so they aren't
    // obscured by the bottom bar.
    if (!kIsWeb) {
      final player = ref.watch(playerProvider);
      _subPosManager ??= SubtitlePositionManager(player: player);

      final subStyle = ref.watch(subtitleStyleProvider);
      _subPosManager!.updateUserPosition(subStyle.verticalPosition);

      final zoomScale = ref.watch(videoZoomScaleProvider);
      final videoHeight = MediaQuery.sizeOf(context).height;

      ref.listen<OsdState>(osdStateProvider, (prev, next) {
        _subPosManager?.onOsdVisibilityChanged(
          visible: next == OsdState.visible,
          barHeightPx: kOsdBottomBarHeight,
          videoHeightPx: videoHeight,
          zoomScale: zoomScale,
        );
      });
    }

    return RepaintBoundary(
      key: screenshotBoundaryKey,
      child: Stack(
        children: [
          // ── Main OSD — fades in/out ──
          // Use osdShow (200 ms) when appearing, osdHide (300 ms) when
          // fading out so the transition matches design-system §4.
          AnimatedOpacity(
            opacity: osdState == OsdState.visible ? 1.0 : 0.0,
            duration:
                osdState == OsdState.visible
                    ? CrispyAnimation.osdShow
                    : CrispyAnimation.osdHide,
            curve: CrispyAnimation.scrollCurve,
            child: IgnorePointer(
              ignoring: osdState != OsdState.visible,
              child: ExcludeFocus(
                // Exclude focus when OSD is hidden, OR when using
                // mouse/touch — prevents Material buttons from
                // stealing keyboard focus on mouse click.
                excluding:
                    osdState != OsdState.visible ||
                    inputMode == InputMode.mouse ||
                    inputMode == InputMode.touch,
                child:
                    showContent
                        ? _buildOsdContent(context)
                        : const SizedBox.shrink(),
              ),
            ),
          ),

          // Stats overlay
          Consumer(
            builder: (context, ref, _) {
              return ref.watch(streamStatsVisibleProvider)
                  ? const StreamStatsOverlay()
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  /// Builds the full OSD content (top bar, center
  /// controls, bottom bar). Only called when OSD is
  /// visible or fading to avoid expensive provider
  /// watches when hidden.
  Widget _buildOsdContent(BuildContext context) {
    // We do NOT watch playbackStateProvider directly here, because its
    // `position` ticks 60 times a second, which would rebuild the ENTIRE
    // OSD tree. Instead we selectively watch only what the static layout
    // needs.
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Extract non-ticking static properties to build the skeleton
    final isTrulyLive = ref.watch(
      playbackStateProvider.select(
        (s) =>
            (s.value?.isLive ?? false) || (s.value?.duration == Duration.zero),
      ),
    );
    final channelName = ref.watch(
      playbackStateProvider.select((s) => s.value?.channelName),
    );
    final channelLogoUrl = ref.watch(
      playbackStateProvider.select((s) => s.value?.channelLogoUrl),
    );
    final sleepTimerRemaining = ref.watch(
      playbackStateProvider.select((s) => s.value?.sleepTimerRemaining),
    );
    final videoFormat = ref.watch(
      playbackStateProvider.select((s) => s.value?.videoFormat),
    );
    final audioFormat = ref.watch(
      playbackStateProvider.select((s) => s.value?.audioFormat),
    );
    final is4k = ref.watch(
      playbackStateProvider.select((s) => s.value?.is4k ?? false),
    );

    return FocusTraversalGroup(
      child: Stack(
        children: [
          // ── Top gradient + top bar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MouseRegion(
              onEnter: (_) => ref.read(osdStateProvider.notifier).freezeTimer(),
              onExit:
                  (_) => ref.read(osdStateProvider.notifier).unfreezeTimer(),
              child: OsdTopBar(
                channelName: channelName,
                channelLogoUrl: channelLogoUrl,
                channelEpgId: widget.channelEpgId,
                isLive: isTrulyLive,
                sleepTimerRemaining: sleepTimerRemaining,
                videoFormat: videoFormat,
                audioFormat: audioFormat,
                is4k: is4k,
                colorScheme: colorScheme,
                textTheme: textTheme,
                onBack: widget.onBack,
              ),
            ),
          ),

          // ── Center controls ──
          Center(
            child: FocusTraversalGroup(
              child: Consumer(
                builder: (context, ref, _) {
                  final isPlaying = ref.watch(
                    playbackStateProvider.select(
                      (s) => s.value?.isPlaying ?? false,
                    ),
                  );

                  return OsdCenterControls(
                    isPlaying: isPlaying,
                    isLive: isTrulyLive,
                    onPlayPause: () {
                      ref.read(playerServiceProvider).playOrPause();
                      ref.read(osdStateProvider.notifier).show();
                    },
                    onSeekBack:
                        isTrulyLive
                            ? null
                            : () {
                              seekRelative(ref, -CrispyAnimation.seekStep);
                              ref.read(osdStateProvider.notifier).show();
                            },
                    onSeekForward:
                        isTrulyLive
                            ? null
                            : () {
                              seekRelative(ref, CrispyAnimation.seekStep);
                              ref.read(osdStateProvider.notifier).show();
                            },
                  );
                },
              ),
            ),
          ),

          // Live EPG strip removed — programme info is already
          // shown in the top bar (OsdTopBar) via channelEpgId.

          // ── Bottom gradient + controls ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MouseRegion(
              onEnter: (_) => ref.read(osdStateProvider.notifier).freezeTimer(),
              onExit:
                  (_) => ref.read(osdStateProvider.notifier).unfreezeTimer(),
              child: OsdBottomBar(
                // DO NOT PASS `state: state` down. The bottom bar
                // component watches internally.
                colorScheme: colorScheme,
                textTheme: textTheme,
                isFavorite: widget.isFavorite,
                channelEpgId: isTrulyLive ? widget.channelEpgId : null,
                onPlayPause: () {
                  ref.read(playerServiceProvider).playOrPause();
                  ref.read(osdStateProvider.notifier).show();
                },
                onVolumeChange: (vol) {
                  ref.read(playerServiceProvider).setVolume(vol);
                },
                onToggleMute: () {
                  ref.read(playerServiceProvider).toggleMute();
                },
                onSeek: (value) {
                  final currentDuration =
                      ref.read(playbackStateProvider).value?.duration ??
                      Duration.zero;
                  final pos = Duration(
                    milliseconds:
                        (value * currentDuration.inMilliseconds).round(),
                  );
                  ref.read(playerServiceProvider).seek(pos);
                },
                onAudioTrack: () {
                  final state = ref.read(playbackStateProvider).value;
                  if (state != null) {
                    showAudioTrackPicker(context, ref, state);
                  }
                },
                onSubtitleTrack: () {
                  final state = ref.read(playbackStateProvider).value;
                  if (state != null) {
                    showSubtitleTrackPicker(context, ref, state);
                  }
                },
                onSpeed: () {
                  final currentSpeed =
                      ref.read(playbackStateProvider).value?.speed ?? 1.0;
                  cyclePlaybackSpeed(
                    currentSpeed: currentSpeed,
                    setSpeed:
                        (speed) =>
                            ref.read(playerServiceProvider).setSpeed(speed),
                  );
                  ref.read(osdStateProvider.notifier).show();
                },
                onToggleFullscreen: widget.onToggleFullscreen,
                onFavorite: widget.onFavorite,
                onEnterPip: widget.onEnterPip,
                onSleepTimer: widget.onSleepTimer,
                onOpenExternal: widget.onOpenExternal,
                onCopyUrl: widget.onCopyUrl,
                onRefresh: () {
                  ref.read(playerServiceProvider).refresh();
                  ref.read(osdStateProvider.notifier).show();
                },
                onAspectRatio: () {
                  ref.read(playerServiceProvider).cycleAspectRatio();
                  ref.read(osdStateProvider.notifier).show();
                },
                onStreamInfo:
                    () => ref
                        .read(streamStatsVisibleProvider.notifier)
                        .update((state) => !state),
                onSearch: widget.onSearch,
                onChannelList: widget.onChannelList,
                onRecordings: widget.onRecordings,
                onScreenshot: kIsWeb ? null : _captureScreenshot,
                onToggleLock: () {
                  ref.read(playerLockedProvider.notifier).toggle();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
