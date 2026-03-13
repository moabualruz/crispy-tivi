import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/watch_progress_bar.dart';
import '../../domain/entities/playback_state.dart';
import '../../domain/player_lifecycle_coordinator.dart';
import '../providers/player_providers.dart';

/// Persistent mini-player bar shown in [AppShell] when
/// media is actively playing or paused.
///
/// Shows channel/VOD name, play/pause toggle, and close.
/// Tapping the bar navigates to the full-screen player.
/// Slides in from below when it becomes visible and slides
/// out when dismissed.
///
/// Gesture support:
/// - Swipe **up** (velocity > 500 px/s) → fullscreen.
/// - Swipe **down** (velocity > 500 px/s) → stop + idle.
/// - Tap → fullscreen.
class MiniPlayerBar extends ConsumerStatefulWidget {
  const MiniPlayerBar({super.key});

  @override
  ConsumerState<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<MiniPlayerBar>
    with SingleTickerProviderStateMixin {
  bool _visible = false;

  // ── Swipe gesture state ─────────────────────────────────────

  /// Minimum px/s to trigger a swipe action.
  static const double _swipeVelocityThreshold = 500;

  // ── Helpers ─────────────────────────────────────────────────

  static IconData _volumeIcon(double volume, bool isMuted) {
    if (isMuted || volume <= 0) return Icons.volume_off_rounded;
    if (volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  void _enterFullscreen() {
    final currentRoute = ref.read(playerModeProvider).currentRoute;
    ref
        .read(playerModeProvider.notifier)
        .enterFullscreen(hostRoute: currentRoute);
    ref.read(playerServiceProvider).forceStateEmit();
  }

  void _dismiss() {
    ref.read(playerServiceProvider).stop();
    ref.read(playerModeProvider.notifier).setIdle();
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity < -_swipeVelocityThreshold) {
      // Fast upward swipe → fullscreen.
      _enterFullscreen();
    } else if (velocity > _swipeVelocityThreshold) {
      // Fast downward swipe → dismiss.
      _dismiss();
    }
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Full playback snapshot for controls.
    final data = ref.watch(
      playbackStateProvider.select(
        (async) => async.whenData(
          (s) => (
            status: s.status,
            channelName: s.channelName,
            channelLogoUrl: s.channelLogoUrl,
            isLive: s.isLive,
            currentProgram: s.currentProgram,
            isPlaying: s.isPlaying,
            volume: s.volume,
            isMuted: s.isMuted,
          ),
        ),
      ),
    );

    // Separate selector for progress to avoid rebuilding the
    // whole bar on every position tick — only the indicator
    // needs position + duration.
    final progress = ref.watch(
      playbackStateProvider.select((async) => async.value?.progress ?? 0.0),
    );

    final isLiveBar = ref.watch(
      playbackStateProvider.select((async) => async.value?.isLive ?? false),
    );

    final mode = ref.watch(playerModeProvider.select((s) => s.mode));

    final state = data.value;
    final status = state?.status ?? PlaybackStatus.idle;
    final shouldShow =
        state != null &&
        state.channelName != null &&
        PlayerLifecycleCoordinator.shouldShowMiniPlayer(mode, status);

    // Schedule visibility update after build to avoid
    // setState-during-build errors.
    if (shouldShow != _visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = shouldShow);
      });
    }

    if (state == null || (!shouldShow && !_visible)) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 1),
      duration: CrispyAnimation.normal,
      curve: _visible ? CrispyAnimation.enterCurve : CrispyAnimation.exitCurve,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: CrispyAnimation.normal,
        child: Semantics(
          button: true,
          label: context.l10n.playerExpandToFullscreen,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enterFullscreen,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Material(
              color: Colors.transparent,
              child: GlassSurface(
                borderRadius: CrispyRadius.md,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── 2 dp progress bar ───────────────────
                    SizedBox(
                      height: CrispySpacing.xxs,
                      child:
                          isLiveBar
                              // Live: solid primary colour, no progress.
                              ? LinearProgressIndicator(
                                value: 1.0,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                                minHeight: CrispySpacing.xxs,
                              )
                              // VOD: track position / duration.
                              : WatchProgressBar(
                                value: progress,
                                height: CrispySpacing.xxs,
                                backgroundColor: colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                              ),
                    ),

                    // ── Main bar row ────────────────────────
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(
                        horizontal: CrispySpacing.md,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.zero,
                        border: Border(
                          top: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Channel logo
                          Padding(
                            padding: const EdgeInsets.only(
                              right: CrispySpacing.sm,
                            ),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: SmartImage(
                                title: state.channelName ?? '',
                                imageUrl: state.channelLogoUrl,
                                imageKind: 'logo',
                                fit: BoxFit.contain,
                                icon: Icons.live_tv,
                                memCacheWidth: 72,
                                memCacheHeight: 72,
                              ),
                            ),
                          ),

                          // Channel name + LIVE badge / program title
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.channelName ?? '',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (state.isLive)
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.rectangle,
                                          color:
                                              Theme.of(
                                                context,
                                              ).crispyColors.liveRed,
                                        ),
                                      ),
                                      const SizedBox(width: CrispySpacing.xs),
                                      Text(
                                        'LIVE',
                                        style: textTheme.labelSmall?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).crispyColors.liveRed,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                else if (state.currentProgram != null)
                                  Text(
                                    state.currentProgram!,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),

                          // Play/Pause button
                          IconButton(
                            onPressed: () {
                              ref.read(playerServiceProvider).playOrPause();
                            },
                            icon: Icon(
                              state.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 28,
                            ),
                            tooltip:
                                state.isPlaying
                                    ? context.l10n.commonPause
                                    : context.l10n.commonPlay,
                          ),

                          // Mute/Unmute button
                          IconButton(
                            onPressed:
                                () =>
                                    ref
                                        .read(playerServiceProvider)
                                        .toggleMute(),
                            icon: Icon(
                              _volumeIcon(state.volume, state.isMuted),
                              size: 22,
                            ),
                            tooltip:
                                state.isMuted
                                    ? context.l10n.playerUnmute
                                    : context.l10n.playerMute,
                          ),

                          // Close button
                          IconButton(
                            onPressed: _dismiss,
                            icon: const Icon(Icons.close_rounded, size: 22),
                            tooltip: context.l10n.playerStopPlayback,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
