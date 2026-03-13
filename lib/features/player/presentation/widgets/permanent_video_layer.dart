import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../domain/entities/playback_state.dart';
import '../../domain/player_lifecycle_coordinator.dart';
import '../providers/player_providers.dart';
import 'web_hls_video.dart';

/// Maps an aspect ratio label from settings to [BoxFit].
BoxFit boxFitFromLabel(String label) {
  switch (label) {
    case 'Fill':
      return BoxFit.cover;
    case 'Fit':
      return BoxFit.fill;
    case 'Original':
    case '16:9':
    case '4:3':
    default:
      return BoxFit.contain;
  }
}

/// Always-mounted video surface positioned by [playerModeProvider].
///
/// ONE video element for the entire app — platform chooses the
/// rendering widget (native [Video] or web [WebHlsVideo]) but
/// it is the SAME single playback element that moves/resizes,
/// never recreated.
///
/// Position is controlled via [AnimatedPositioned] based on
/// [PlayerModeState.mode] and [PlayerModeState.previewRect].
class PermanentVideoLayer extends ConsumerWidget {
  const PermanentVideoLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeState = ref.watch(playerModeProvider);
    final playbackStatus = ref.watch(
      playbackStateProvider.select(
        (a) => a.whenData((s) => s.status).value ?? PlaybackStatus.idle,
      ),
    );

    // Use coordinator to decide whether to mount the video surface.
    final shouldMount = PlayerLifecycleCoordinator.shouldMountSurface(
      modeState.mode,
      playbackStatus,
    );

    final screenSize = MediaQuery.sizeOf(context);
    final fullRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

    // Compute target rect and visibility.
    Rect targetRect;
    double opacity;
    // Use fast animation for preview mode transitions,
    // normal for fullscreen transitions, and Duration.zero
    // for rect-only updates (sidebar resize) so the Platform
    // View snaps to each frame's position without lag.
    var duration = CrispyAnimation.normal;

    switch (modeState.mode) {
      case PlayerMode.idle:
      case PlayerMode.background:
        // Park offscreen at full natural size — eliminates the
        // shrink animation on mode exit and the "fly in from
        // corner" on re-entry. Duration.zero snaps instantly.
        targetRect = Rect.fromLTWH(
          -screenSize.width - 1,
          -screenSize.height - 1,
          screenSize.width,
          screenSize.height,
        );
        opacity = 0.0;
        duration = Duration.zero;
      case PlayerMode.preview:
        // Hide when navigated away from host screen (EPG →
        // Home) or when preview rect isn't reported yet.
        final rect = modeState.previewRect;
        final hasRect = rect != null && !rect.isEmpty;
        if (modeState.isOnHostRoute && hasRect) {
          targetRect = rect;
          opacity = 1.0;
        } else {
          targetRect = Rect.fromLTWH(
            -screenSize.width - 1,
            -screenSize.height - 1,
            screenSize.width,
            screenSize.height,
          );
          opacity = 0.0;
        }
        // Rect-only updates (e.g. sidebar resize): snap
        // instantly so the video tracks the layout reflow
        // each frame. Mode transitions: animate smoothly.
        duration =
            modeState.isRectOnlyUpdate ? Duration.zero : CrispyAnimation.fast;
      case PlayerMode.fullscreen:
        final guideSplit = ref.watch(guideSplitProvider);
        if (guideSplit) {
          // Guide split: video occupies the left half.
          targetRect = Rect.fromLTWH(
            0,
            0,
            screenSize.width / 2,
            screenSize.height,
          );
        } else {
          targetRect = fullRect;
        }
        opacity = 1.0;
    }

    return AnimatedPositioned(
      duration: duration,
      curve: CrispyAnimation.enterCurve,
      left: targetRect.left,
      top: targetRect.top,
      width: targetRect.width,
      height: targetRect.height,
      child: AnimatedOpacity(
        duration: CrispyAnimation.normal,
        opacity: opacity,
        child: Visibility(
          // Hard-hide the element on web — AnimatedOpacity alone
          // doesn't reliably hide HTML platform views.
          visible: opacity > 0,
          maintainState: true,
          maintainSize: false,
          child: IgnorePointer(
            // Video surface never captures taps — OSD layer
            // and screen content handle all interaction.
            child: Container(
              color: Colors.black,
              // Mount the video surface only when the coordinator
              // says so (mode is preview or fullscreen). This avoids
              // pulling in MediaKit during golden tests while
              // keeping the surface alive across preview ↔
              // fullscreen transitions.
              child:
                  !shouldMount
                      ? const SizedBox.shrink()
                      // FE-PS-19: wrap video in Transform.scale for
                      // pinch-to-zoom support. Scale is managed by
                      // [videoZoomScaleProvider] (1.0–3.0).
                      : _ZoomedVideoSurface(
                        child: _buildVideoSurface(context, ref),
                      ),
            ),
          ),
        ),
      ),
    );
  }

  // Extracted so linter sees it's used in build.
  Widget _buildVideoSurface(BuildContext context, WidgetRef ref) {
    // Read aspect ratio label from playback state.
    final aspectLabel = ref.watch(
      playbackStateProvider.select(
        (a) => a.whenData((s) => s.aspectRatioLabel).value ?? 'Auto',
      ),
    );
    final fit = boxFitFromLabel(aspectLabel);

    // Web path: WebHlsVideo with stats callback integration.
    if (kIsWeb) {
      final playerService = ref.read(playerServiceProvider);
      return WebHlsVideo(
        key: playerService.webVideoKey,
        streamUrl: playerService.currentUrl ?? '',
        onVideoIdReady: (videoId) {
          playerService.attachWebVideo(videoId);
          if (playerService.currentUrl != null) {
            playerService.play(playerService.currentUrl!, isLive: true);
          }
        },
        onStatsUpdate: (stats) {
          playerService.updateExternalStreamInfo(stats);
        },
      );
    }

    // Native path: delegate to CrispyPlayer's video widget.
    final player = ref.watch(playerProvider);
    return player.buildVideoWidget(fit: fit);
  }
}

/// FE-PS-19: Reads [videoZoomScaleProvider] and wraps [child]
/// with an animated [Transform.scale]. Kept as a separate
/// [ConsumerWidget] so only this subtree rebuilds on scale changes.
class _ZoomedVideoSurface extends ConsumerWidget {
  const _ZoomedVideoSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(videoZoomScaleProvider);
    return AnimatedScale(
      scale: scale,
      duration: CrispyAnimation.extraFast,
      child: child,
    );
  }
}
