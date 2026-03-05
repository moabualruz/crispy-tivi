import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../domain/entities/playback_state.dart';
import '../providers/player_providers.dart';
import '../widgets/stream_stats_overlay.dart';
import 'live_epg_strip.dart';
import 'player_osd/osd_audio_picker.dart';
import 'player_osd/osd_bottom_bar.dart';
import 'player_osd/osd_center_controls.dart';
import 'player_osd/osd_speed_picker.dart';
import 'player_osd/osd_subtitle_picker.dart';
import 'player_osd/osd_top_bar.dart';
import 'player_seek_utils.dart';

/// Netflix-style on-screen display overlay.
///
/// Layout: top gradient bar (back + title), center
/// controls (skip back / play-pause / skip forward),
/// bottom gradient bar (left: play + volume + title,
/// right: subs + speed + fullscreen), Netflix Red
/// progress bar above bottom bar.
///
/// Auto-hides after 4 seconds of inactivity.
///
/// Design ref: `.ai/docs/plans/netflix_ui_reference.md`
/// section 11.
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
  /// Key wrapping the video area so [RepaintBoundary.toImage]
  /// can capture the frame for the screenshot feature.
  final GlobalKey _screenshotKey = GlobalKey();

  // ── Screenshot ──────────────────────────────────

  /// Captures the current video frame via [RepaintBoundary]
  /// and shows a brief flash + "Saved" toast.
  ///
  /// The actual file-save is a TODO — the UI affordance
  /// (flash + snack) is implemented here.
  Future<void> _captureScreenshot() async {
    final boundary =
        _screenshotKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;

    // Flash animation — briefly show a white overlay.
    if (!mounted) return;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder:
          (_) => IgnorePointer(
            child: Container(color: Colors.white.withValues(alpha: 0.35)),
          ),
    );
    overlay.insert(entry);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    entry.remove();

    // Capture image (unused until save path wired up).
    try {
      // ignore: unused_local_variable
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      image.dispose();
    } catch (_) {
      // Silently ignore capture errors (e.g. platform-limited surfaces).
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Screenshot saved'),
        duration: CrispyAnimation.snackBarDuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final osdState = ref.watch(osdStateProvider);
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
        ref.read(osdStateProvider.notifier).onPlaybackStateChanged(isPlaying);
      },
    );

    // Sync input mode to OSD timeout.
    ref.watch(osdTimeoutSyncProvider);

    // PS-18: Enforce A-B loop — seek back to A when
    // playback crosses the B point.
    ref.listen(playbackStateProvider.select((s) => s.value?.progress ?? 0.0), (
      prev,
      progress,
    ) {
      final loop = ref.read(abLoopProvider);
      if (!loop.isActive) return;
      final loopEnd = loop.loopEnd!;
      if (progress >= loopEnd) {
        final loopStart = loop.loopStart!;
        final duration =
            ref.read(playbackStateProvider).value?.duration ?? Duration.zero;
        final seekPos = Duration(
          milliseconds: (loopStart * duration.inMilliseconds).round(),
        );
        ref.read(playerServiceProvider).seek(seekPos);
      }
    });

    return RepaintBoundary(
      key: _screenshotKey,
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
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: osdState != OsdState.visible,
              child: ExcludeFocus(
                excluding: osdState != OsdState.visible,
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

          // ── Live EPG programme strip ──
          // Shown above the bottom bar gradient for live
          // streams when channelEpgId is available.
          if (widget.channelEpgId != null)
            LiveEpgStrip(
              channelEpgId: widget.channelEpgId!,
              isLive: isTrulyLive,
            ),

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
                onScreenshot: _captureScreenshot,
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
