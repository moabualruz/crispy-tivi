import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';

import '../../../../../core/theme/crispy_animation.dart';
import '../../../../../core/theme/crispy_colors.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/data/cache_service.dart';
import '../../providers/player_providers.dart';
import '../seek_bar_with_preview.dart';
import 'osd_ab_loop_button.dart';
import 'osd_mini_guide.dart';
import 'osd_overflow_menu.dart';
import 'osd_shared.dart';
import 'osd_speed_picker.dart';

/// Bottom bar -- Netflix style.
///
/// Layout (top to bottom):
/// 1. Mini EPG guide strip (live TV only, FE-EPG-07)
/// 2. Full-width progress bar (red fill, expandable)
///    — with A-B loop markers for VOD (PS-18)
/// 3. Controls row: left group (play, volume, title)
///    + right group (A-B, subs, speed, overflow, fullscreen)
class OsdBottomBar extends ConsumerWidget {
  const OsdBottomBar({
    required this.colorScheme,
    required this.textTheme,
    required this.isFavorite,
    required this.onPlayPause,
    required this.onVolumeChange,
    required this.onToggleMute,
    required this.onSeek,
    required this.onAudioTrack,
    required this.onSubtitleTrack,
    required this.onSpeed,
    required this.onRefresh,
    required this.onAspectRatio,
    required this.onStreamInfo,
    this.channelEpgId,
    this.onToggleFullscreen,
    this.onFavorite,
    this.onEnterPip,
    this.onSleepTimer,
    this.onOpenExternal,
    this.onCopyUrl,
    this.onSearch,
    this.onChannelList,
    this.onRecordings,
    this.onScreenshot,
    this.onToggleLock,
    super.key,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isFavorite;

  /// EPG channel ID used to display the mini guide strip
  /// above the seek bar during live TV playback (FE-EPG-07).
  final String? channelEpgId;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onVolumeChange;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onSeek;
  final VoidCallback onAudioTrack;
  final VoidCallback onSubtitleTrack;
  final VoidCallback onSpeed;
  final VoidCallback onRefresh;
  final VoidCallback onAspectRatio;
  final VoidCallback onStreamInfo;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onFavorite;
  final VoidCallback? onEnterPip;
  final VoidCallback? onSleepTimer;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onCopyUrl;
  final VoidCallback? onSearch;
  final VoidCallback? onChannelList;
  final VoidCallback? onRecordings;

  /// Optional callback to capture a screenshot of the player.
  final VoidCallback? onScreenshot;

  /// Optional callback to toggle the touch lock on/off.
  final VoidCallback? onToggleLock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTrulyLive = ref.watch(
      playbackStateProvider.select(
        (s) =>
            (s.value?.isLive ?? false) || (s.value?.duration == Duration.zero),
      ),
    );

    return Container(
      decoration: const BoxDecoration(gradient: osdBottomGradient),
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + CrispySpacing.sm,
        left: CrispySpacing.md,
        right: CrispySpacing.md,
        top: CrispySpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // -- FE-EPG-07: Mini EPG guide (live TV only) --
          if (isTrulyLive && channelEpgId != null)
            OsdMiniGuide(
              channelEpgId: channelEpgId!,
              isLive: true,
              textTheme: textTheme,
            ),

          // -- Progress bar (full width) --
          if (!isTrulyLive) ...[
            _buildVodSeekBar(),
            const SizedBox(height: CrispySpacing.sm),
          ] else ...[
            Consumer(
              builder: (context, ref, _) {
                final isLive = ref.watch(
                  playbackStateProvider.select((s) => s.value?.isLive ?? false),
                );
                if (isLive) {
                  return Column(
                    children: [
                      _buildLiveBufferBar(),
                      const SizedBox(height: CrispySpacing.sm),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],

          // -- Controls row --
          _buildControlsRow(context, ref, isTrulyLive),
        ],
      ),
    );
  }

  /// VOD seek bar with time labels, Netflix red accent,
  /// and A-B loop markers (PS-18).
  Widget _buildVodSeekBar() {
    return Consumer(
      builder: (context, ref, _) {
        final position = ref.watch(
          playbackStateProvider.select(
            (s) => s.value?.position ?? Duration.zero,
          ),
        );
        final duration = ref.watch(
          playbackStateProvider.select(
            (s) => s.value?.duration ?? Duration.zero,
          ),
        );
        final progress = ref.watch(
          playbackStateProvider.select((s) => s.value?.progress ?? 0.0),
        );
        final bufferProgress = ref.watch(
          playbackStateProvider.select((s) => s.value?.bufferProgress ?? 0.0),
        );
        final loopState = ref.watch(abLoopProvider);

        final backend = ref.read(crispyBackendProvider);
        final durationMs = duration.inMilliseconds;
        return Row(
          children: [
            Text(
              backend.formatPlaybackDuration(
                position.inMilliseconds,
                durationMs,
              ),
              style: textTheme.labelSmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(width: CrispySpacing.sm),
            Expanded(
              child: _AbMarkerSeekBar(
                progress: progress,
                bufferProgress: bufferProgress,
                duration: duration,
                onSeek: onSeek,
                loopStart: loopState.loopStart,
                loopEnd: loopState.loopEnd,
              ),
            ),
            const SizedBox(width: CrispySpacing.sm),
            Text(
              backend.formatPlaybackDuration(durationMs, durationMs),
              style: textTheme.labelSmall?.copyWith(color: Colors.white70),
            ),
          ],
        );
      },
    );
  }

  /// Live buffer indicator bar.
  Widget _buildLiveBufferBar() {
    return Consumer(
      builder: (context, ref, _) {
        final position = ref.watch(
          playbackStateProvider.select(
            (s) => s.value?.position ?? Duration.zero,
          ),
        );
        final bufferProgress = ref.watch(
          playbackStateProvider.select((s) => s.value?.bufferProgress ?? 0.0),
        );
        final bufferLatency = ref.watch(
          playbackStateProvider.select(
            (s) => s.value?.bufferLatency ?? Duration.zero,
          ),
        );

        final backend = ref.read(crispyBackendProvider);
        final posMs = position.inMilliseconds;
        return Row(
          children: [
            Text(
              backend.formatPlaybackDuration(posMs, posMs),
              style: textTheme.labelSmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(width: CrispySpacing.sm),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(CrispyRadius.progressBar),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    children: [
                      Container(color: Colors.white.withValues(alpha: 0.2)),
                      if (bufferProgress > 0)
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: bufferProgress.clamp(0.0, 1.0),
                          child: Container(
                            color: CrispyColors.netflixRed.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (bufferLatency > Duration.zero) ...[
              const SizedBox(width: CrispySpacing.sm),
              Text(
                '${bufferLatency.inMilliseconds}ms',
                style: textTheme.labelSmall?.copyWith(color: Colors.white54),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Netflix-style controls row.
  ///
  /// Left: play/pause, volume, title.
  /// Right: subs/CC, speed (VOD), overflow, fullscreen.
  Widget _buildControlsRow(
    BuildContext context,
    WidgetRef ref,
    bool isLiveStream,
  ) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Row(
        children: [
          // -- Left group --
          // Play/Pause (small)
          Consumer(
            builder: (context, ref, _) {
              final isPlaying = ref.watch(
                playbackStateProvider.select(
                  (s) => s.value?.isPlaying ?? false,
                ),
              );
              return OsdIconButton(
                icon:
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                tooltip: isPlaying ? 'Pause' : 'Play',
                onPressed: onPlayPause,
                order: 1,
              );
            },
          ),

          // Volume
          FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: Consumer(
              builder: (context, ref, _) {
                final volume = ref.watch(
                  playbackStateProvider.select((s) => s.value?.volume ?? 1.0),
                );
                final isMuted = ref.watch(
                  playbackStateProvider.select(
                    (s) => s.value?.isMuted ?? false,
                  ),
                );
                return OsdVolumeButton(
                  volume: volume,
                  isMuted: isMuted,
                  onVolumeChange: onVolumeChange,
                  onToggleMute: onToggleMute,
                );
              },
            ),
          ),

          const SizedBox(width: CrispySpacing.md),

          // -- Quick Access Shortcuts --
          if (onSearch != null)
            OsdIconButton(
              icon: Icons.search,
              tooltip: 'Search',
              onPressed: onSearch!,
              order: 2.1,
            ),
          if (onChannelList != null)
            OsdIconButton(
              icon: Icons.list_alt_rounded,
              tooltip: 'Channels',
              onPressed: onChannelList!,
              order: 2.2,
            ),
          if (onRecordings != null)
            OsdIconButton(
              icon: Icons.fiber_manual_record_rounded,
              tooltip: 'Recordings',
              onPressed: onRecordings!,
              order: 2.3,
            ),

          if (onSearch != null || onChannelList != null || onRecordings != null)
            const SizedBox(width: CrispySpacing.sm),

          // Title (truncated)
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final channelName = ref.watch(
                  playbackStateProvider.select(
                    (s) => s.value?.channelName ?? '',
                  ),
                );
                return Text(
                  channelName,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),

          // -- Right group --

          // A-B loop button (VOD only, PS-18)
          OsdAbLoopButton(isLive: isLiveStream, order: 3),

          // Audio & Subtitles (CC icon)
          Builder(
            builder: (context) {
              return Consumer(
                builder: (context, ref, _) {
                  final subtitleCount = ref.watch(
                    playbackStateProvider.select(
                      (s) => s.value?.subtitleTracks.length ?? 0,
                    ),
                  );
                  final audioCount = ref.watch(
                    playbackStateProvider.select(
                      (s) => s.value?.audioTracks.length ?? 0,
                    ),
                  );
                  final hasTracks = subtitleCount > 0 || audioCount > 1;

                  return OsdIconButton(
                    icon: Icons.closed_caption_outlined,
                    tooltip:
                        hasTracks ? 'Audio & Subtitles' : 'No tracks available',
                    onPressed: hasTracks ? onSubtitleTrack : null,
                    order: 4,
                  );
                },
              );
            },
          ),

          // Playback speed (VOD only)
          Consumer(
            builder: (context, ref, _) {
              final speed = ref.watch(
                playbackStateProvider.select((s) => s.value?.speed ?? 1.0),
              );
              return OsdSpeedButton(
                speed: speed,
                isLive: isLiveStream,
                onPressed: isLiveStream ? null : onSpeed,
                order: 5,
              );
            },
          ),

          // Overflow menu (contains: favorite,
          // AirPlay, Cast, audio track, aspect ratio,
          // sleep timer, PiP, external player,
          // stream info, refresh, search, channels,
          // recordings)
          FocusTraversalOrder(
            order: const NumericFocusOrder(6),
            child: Consumer(
              builder: (context, ref, _) {
                final aspectRatioLabel = ref.watch(
                  playbackStateProvider.select(
                    (s) => s.value?.aspectRatioLabel ?? 'Auto',
                  ),
                );
                final isLive = ref.watch(
                  playbackStateProvider.select((s) => s.value?.isLive ?? false),
                );

                return OsdOverflowMenu(
                  onAudioTrack: onAudioTrack,
                  onAspectRatio: onAspectRatio,
                  onRefresh: onRefresh,
                  onStreamInfo: onStreamInfo,
                  onEnterPip: onEnterPip,
                  onSleepTimer: onSleepTimer,
                  onCopyUrl: onCopyUrl,
                  onOpenExternal: onOpenExternal,
                  onSearch: onSearch,
                  onChannelList: onChannelList,
                  onRecordings: onRecordings,
                  onFavorite: onFavorite,
                  onScreenshot: onScreenshot,
                  isFavorite: isFavorite,
                  aspectRatioLabel: aspectRatioLabel,
                  isLive: isLive,
                );
              },
            ),
          ),

          // Touch lock toggle
          if (onToggleLock != null)
            Consumer(
              builder: (context, ref, _) {
                final isLocked = ref.watch(playerLockedProvider);
                return OsdIconButton(
                  icon: isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  tooltip: isLocked ? 'Unlock Screen' : 'Lock Screen',
                  onPressed: onToggleLock,
                  iconColor: isLocked ? Colors.amber : null,
                  order: 7,
                );
              },
            ),

          // Fullscreen toggle (Web/Desktop)
          if (onToggleFullscreen != null &&
              (kIsWeb ||
                  Platform.isWindows ||
                  Platform.isMacOS ||
                  Platform.isLinux))
            Consumer(
              builder: (context, ref, _) {
                final isFullscreen = ref.watch(
                  playbackStateProvider.select(
                    (s) => s.value?.isFullscreen ?? false,
                  ),
                );
                return OsdIconButton(
                  icon:
                      isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                  tooltip: isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                  onPressed: onToggleFullscreen!,
                  order: 8,
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Volume button with hover slider.
class OsdVolumeButton extends StatefulWidget {
  const OsdVolumeButton({
    required this.volume,
    required this.isMuted,
    required this.onVolumeChange,
    required this.onToggleMute,
    super.key,
  });

  final double volume;
  final bool isMuted;
  final ValueChanged<double> onVolumeChange;
  final VoidCallback onToggleMute;

  @override
  State<OsdVolumeButton> createState() => _OsdVolumeButtonState();
}

class _OsdVolumeButtonState extends State<OsdVolumeButton> {
  bool _showSlider = false;
  bool _isFocused = false;

  bool get _sliderVisible => _showSlider || _isFocused;

  IconData get _volumeIcon {
    if (widget.isMuted || widget.volume <= 0) {
      return Icons.volume_off_rounded;
    }
    if (widget.volume < 0.5) {
      return Icons.volume_down_rounded;
    }
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _showSlider = true),
      onExit: (_) => setState(() => _showSlider = false),
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
        skipTraversal: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OsdIconButton(
              icon: _volumeIcon,
              tooltip: 'Volume',
              onPressed: widget.onToggleMute,
            ),
            AnimatedContainer(
              duration: CrispyAnimation.fast,
              width: _sliderVisible ? 80 : 0,
              curve: Curves.easeInOut,
              child:
                  _sliderVisible
                      ? SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: widget.volume,
                          onChanged: widget.onVolumeChange,
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  A-B marker seek bar (PS-18)
// ─────────────────────────────────────────────────────────────

/// Wraps [SeekBarWithPreview] and draws A and B marker
/// lines on top of the track when an A-B loop is active.
class _AbMarkerSeekBar extends StatelessWidget {
  const _AbMarkerSeekBar({
    required this.progress,
    required this.bufferProgress,
    required this.duration,
    required this.onSeek,
    this.loopStart,
    this.loopEnd,
  });

  final double progress;
  final double bufferProgress;
  final Duration duration;
  final ValueChanged<double> onSeek;

  /// A-B loop start fraction (0.0 – 1.0), or null when
  /// not set.
  final double? loopStart;

  /// A-B loop end fraction (0.0 – 1.0), or null when
  /// not set.
  final double? loopEnd;

  @override
  Widget build(BuildContext context) {
    final hasMarkers = loopStart != null || loopEnd != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Underlying seek bar
        SeekBarWithPreview(
          progress: progress,
          bufferProgress: bufferProgress,
          duration: duration,
          onSeek: onSeek,
          accentColor: CrispyColors.netflixRed,
        ),

        // A-B markers overlay
        if (hasMarkers)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Loop region highlight
                    if (loopStart != null && loopEnd != null)
                      Positioned(
                        left: loopStart! * width,
                        width: (loopEnd! - loopStart!).clamp(0.0, 1.0) * width,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          color: Colors.amber.withValues(alpha: 0.15),
                        ),
                      ),

                    // A marker
                    if (loopStart != null)
                      Positioned(
                        left: loopStart! * width - 1,
                        top: 0,
                        bottom: 0,
                        child: _AbMarker(label: 'A'),
                      ),

                    // B marker
                    if (loopEnd != null)
                      Positioned(
                        left: loopEnd! * width - 1,
                        top: 0,
                        bottom: 0,
                        child: _AbMarker(label: 'B'),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Vertical marker line with A or B label above it.
class _AbMarker extends StatelessWidget {
  const _AbMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Label chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.xxs),
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(CrispyRadius.tvSm),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
        ),

        // Vertical line
        Expanded(child: Container(width: 2, color: Colors.amber)),
      ],
    );
  }
}
