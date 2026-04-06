import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';

import '../../../../../core/data/cache_service.dart';
import '../../../../../core/theme/crispy_colors.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../data/shader_service.dart';
import '../../providers/player_providers.dart';
import 'osd_bottom_bar_dialogs.dart';
import 'osd_overflow_menu.dart';
import 'osd_shared.dart';
import 'osd_speed_picker.dart';
import 'osd_volume_button.dart';
import '../player_queue_overlay.dart';
import '../seek_bar_with_preview.dart';

/// Bottom bar.
///
/// Layout (top to bottom):
/// 1. Mini EPG guide strip (live TV only, FE-EPG-07)
/// 2. Full-width progress bar (red fill, expandable)
/// 3. Controls row: left group (play, volume, title)
///    + right group (subs, speed, overflow, fullscreen)
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
          // Mini EPG guide removed — programme info shown in OsdTopBar.

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

  /// VOD seek bar with time labels and brand red accent.
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
        final bufferRanges = ref.watch(bufferRangesProvider);
        final skipSegments = ref.watch(
          playbackStateProvider.select(
            (s) => s.value?.skipSegments ?? const [],
          ),
        );

        final backend = ref.read(crispyBackendProvider);
        final durationMs = duration.inMilliseconds;
        final speed = ref.watch(
          playbackStateProvider.select((s) => s.value?.speed ?? 1.0),
        );
        final showFinish = ref.watch(showFinishTimeProvider);
        final remaining = duration - position;

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
              child: SeekBarWithPreview(
                progress: progress,
                bufferProgress: bufferProgress,
                bufferRanges: bufferRanges,
                skipSegments: skipSegments,
                duration: duration,
                onSeek: onSeek,
                accentColor: CrispyColors.brandRed,
              ),
            ),
            const SizedBox(width: CrispySpacing.sm),
            Text(
              buildRemainingText(
                context,
                backend,
                remaining,
                durationMs,
                speed,
                showFinish,
              ),
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
                            color: CrispyColors.brandRed.withValues(alpha: 0.8),
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

  /// Controls row.
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
                tooltip:
                    isPlaying
                        ? context.l10n.commonPause
                        : context.l10n.commonPlay,
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
                final maxVol = ref.watch(maxVolumeProvider);
                return OsdVolumeButton(
                  volume: volume,
                  isMuted: isMuted,
                  onVolumeChange: onVolumeChange,
                  onToggleMute: onToggleMute,
                  maxVolume: maxVol,
                );
              },
            ),
          ),

          const SizedBox(width: CrispySpacing.md),

          // -- Quick Access Shortcuts --
          if (onSearch != null)
            OsdIconButton(
              icon: Icons.search,
              tooltip: context.l10n.playerSearchChannels,
              onPressed: onSearch!,
              order: 2.1,
            ),
          if (onChannelList != null)
            OsdIconButton(
              icon: Icons.list_alt_rounded,
              tooltip: context.l10n.playerChannelList,
              onPressed: onChannelList!,
              order: 2.2,
            ),
          if (onRecordings != null)
            OsdIconButton(
              icon: Icons.fiber_manual_record_rounded,
              tooltip: context.l10n.playerRecordings,
              onPressed: onRecordings!,
              order: 2.3,
            ),
          // TV guide split toggle (large layouts only).
          if (isLiveStream && MediaQuery.sizeOf(context).width >= 1200)
            Consumer(
              builder: (context, ref, _) {
                final isGuideOpen = ref.watch(guideSplitProvider);
                return OsdIconButton(
                  icon: Icons.live_tv_rounded,
                  tooltip:
                      isGuideOpen
                          ? context.l10n.playerCloseGuide
                          : context.l10n.playerTvGuide,
                  onPressed: () {
                    ref.read(guideSplitProvider.notifier).toggle();
                  },
                  iconColor: isGuideOpen ? CrispyColors.highlightAmber : null,
                  order: 2.4,
                );
              },
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
                        hasTracks
                            ? context.l10n.playerAudioSubtitles
                            : context.l10n.playerNoTracksAvailable,
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

          // Queue button (only visible when queue has items)
          const OsdQueueButton(order: 5.5),

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
                final deinterlaceMode = ref.watch(runtimeDeinterlaceProvider);
                final streamProfile = ref.watch(runtimeStreamProfileProvider);
                final passthroughEnabled = ref.watch(
                  runtimePassthroughProvider,
                );
                final isOnTop = ref.watch(alwaysOnTopProvider);
                final shaderPreset = ref.watch(shaderPresetProvider);

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
                  streamProfileLabel: streamProfile.label,
                  onQuality: () {
                    showQualityPicker(context, ref);
                  },
                  deinterlaceMode: deinterlaceLabel(deinterlaceMode),
                  onDeinterlace: () {
                    ref.read(runtimeDeinterlaceProvider.notifier).cycle();
                  },
                  onRotationLock: () {
                    showRotationLockDialog(context, ref);
                  },
                  onSyncOffset: () {
                    showSyncOffsetDialog(context);
                  },
                  audioPassthroughEnabled: passthroughEnabled,
                  onAudioPassthrough: () {
                    ref.read(runtimePassthroughProvider.notifier).toggle();
                  },
                  onAudioDevice: () {
                    showAudioDevicePicker(context, ref);
                  },
                  isAlwaysOnTop: isOnTop,
                  onAlwaysOnTop: () {
                    toggleAlwaysOnTop(ref);
                  },
                  onBrightness: () {
                    showBrightnessDialog(context, ref);
                  },
                  shaderPresetLabel: shaderPreset.name,
                  onShaderPreset: () {
                    showShaderPresetPickerDialog(context, ref, shaderPreset);
                  },
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
                  tooltip:
                      isLocked
                          ? context.l10n.playerUnlockScreen
                          : context.l10n.playerLockScreen,
                  onPressed: onToggleLock,
                  iconColor: isLocked ? CrispyColors.highlightAmber : null,
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
                  playerModeProvider.select(
                    (s) => s.mode == PlayerMode.fullscreen,
                  ),
                );
                return OsdIconButton(
                  icon:
                      isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                  tooltip:
                      isFullscreen
                          ? context.l10n.playerExitFullscreen
                          : context.l10n.playerFullscreen,
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
