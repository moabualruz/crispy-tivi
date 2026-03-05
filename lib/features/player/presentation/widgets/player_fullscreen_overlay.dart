import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../favorites/data/favorites_history_service.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../domain/entities/playback_state.dart';
import '../providers/playback_progress_provider.dart';
import '../providers/player_providers.dart';
import '../screens/player_external_launch.dart';
import '../screens/player_keyboard_handler.dart';
import 'player_gesture_handler.dart';
import 'player_history_tracker.dart';
import 'player_lifecycle_handler.dart';
import 'player_mouse_region.dart';
import 'player_gesture_overlays.dart';
import 'player_osd/osd_subtitle_picker.dart';
import 'player_shortcuts_help_overlay.dart';
import 'player_stack.dart';

/// Fullscreen player overlay mounted in [AppShell] Stack layer 2.
///
/// Replaces the standalone [PlayerScreen] + `/player` route.
/// Reads all playback metadata from [playbackSessionProvider]
/// instead of constructor parameters. Includes the full feature
/// set: gestures, keyboard, zapping, watch history, lifecycle
/// management, PiP, and all PlayerStack overlays.
///
/// The video surface is rendered by [PermanentVideoLayer] on
/// the layer below — this overlay passes a transparent
/// placeholder to [PlayerStack].
class PlayerFullscreenOverlay extends ConsumerStatefulWidget {
  const PlayerFullscreenOverlay({super.key});

  @override
  ConsumerState<PlayerFullscreenOverlay> createState() =>
      _PlayerFullscreenOverlayState();
}

class _PlayerFullscreenOverlayState
    extends ConsumerState<PlayerFullscreenOverlay>
    with
        WidgetsBindingObserver,
        WindowListener,
        PlayerLifecycleMixin,
        PlayerGestureMixin,
        PlayerHistoryMixin {
  // ── Zap state ──
  String? _zapChannelName;
  Timer? _zapOverlayTimer;
  bool _showZapOverlay = false;

  // ── Shortcuts help overlay ──
  bool _showShortcutsHelp = false;

  // ── Session tracking ──
  String? _activeStreamUrl;
  late final FocusNode _focusNode;
  PlayerMode? _lastAppliedMode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addObserver(this);
    initWindowListener();
    initFullscreenSync();

    // Defer initial playback setup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncSession();
        _focusNode.requestFocus();
        // Apply initial SystemChrome state after first frame.
        final mode = ref.read(playerModeProvider).mode;
        _applySystemChrome(mode);
        _lastAppliedMode = mode;
      }
    });
  }

  /// Applies [SystemChrome] immersive/orientation settings for the
  /// given [mode] on mobile platforms. Must be called from lifecycle
  /// hooks — never from [build].
  void _applySystemChrome(PlayerMode mode) {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (mode == PlayerMode.fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // On phones, restore the app-wide landscape lock.
      // On tablets, unlock to allow free rotation.
      final isPhone = MediaQuery.sizeOf(context).shortestSide < 600.0;
      SystemChrome.setPreferredOrientations(
        isPhone
            ? [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
            : [],
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      handleAppLifecycleChange(state);

  @override
  void onWindowBlur() => handleWindowBlur();

  @override
  void onWindowFocus() => handleWindowFocus();

  @override
  void onWindowEnterFullScreen() {
    if (mounted) ref.read(playerServiceProvider).setFullscreen(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) {
      ref.read(playerServiceProvider).setFullscreen(false);
      restoreMaximizedState();
    }
  }

  @override
  void dispose() {
    cancelFullscreenListener?.call();
    WidgetsBinding.instance.removeObserver(this);
    if (isWindowListenerRegistered) {
      windowManager.removeListener(this);
    }
    if (isInPip) pipHandler.exitPiP();

    _zapOverlayTimer?.cancel();
    _focusNode.dispose();
    disposeGestures();
    disposeHistory();
    super.dispose();
  }

  // ────────────────────────────────────────────────
  //  Session sync
  // ────────────────────────────────────────────────

  /// Check if session changed and start new playback tracking.
  void _syncSession() {
    final session = ref.read(playbackSessionProvider);
    if (session.streamUrl.isEmpty) return;
    if (session.streamUrl == _activeStreamUrl) return;

    _activeStreamUrl = session.streamUrl;
    _resetTrackingState();

    // Start VOD tracking.
    if (!session.isLive) {
      recordWatchHistory(session);
    }

    // Record live channel to history.
    if (session.isLive && session.channelList != null) {
      final channels = session.channelList!;
      if (session.channelIndex < channels.length) {
        ref
            .read(favoritesHistoryProvider.notifier)
            .addToHistory(channels[session.channelIndex]);
      }
    }

    // Seek to saved position once duration is known.
    if (!session.isLive &&
        session.startPosition != null &&
        session.startPosition!.inSeconds > 0) {
      ProviderSubscription<AsyncValue<PlaybackState>>? seekSub;
      seekSub = ref.listenManual(playbackStateProvider, (prev, next) {
        final state = next.value;
        if (state != null && state.duration.inMilliseconds > 0) {
          if (mounted) {
            ref.read(playerServiceProvider).seek(session.startPosition!);
          }
          seekSub?.close();
        }
      }, fireImmediately: true);
    }

    // AFR setup.
    if (!kIsWeb) {
      final afrEnabled = ref.read(afrEnabledProvider);
      final afrForLive = ref.read(afrLiveTvProvider);
      final afrForVod = ref.read(afrVodProvider);
      final shouldApplyAfr =
          afrEnabled &&
          ((session.isLive && afrForLive) || (!session.isLive && afrForVod));

      if (shouldApplyAfr) {
        final afrService = ref.read(afrServiceProvider);
        afrService.monitor(ref.read(playerServiceProvider).player);
      }
    }
  }

  void _resetTrackingState() {
    // Stop any in-progress position tracking before starting a
    // new session — clears timers and subscriptions in the
    // provider, then resets the widget-layer UI flags.
    try {
      ref.read(playbackProgressProvider.notifier).stopTracking();
    } catch (_) {
      // Provider may not yet be alive on first call.
    }
    resetHistoryState();
    _zapChannelName = null;
    _showZapOverlay = false;
  }

  // ────────────────────────────────────────────────
  //  Channel zapping
  // ────────────────────────────────────────────────

  /// Zap to the channel [direction] steps away in the current list.
  ///
  /// Positive [direction] = next channel, negative = previous.
  void _zapChannel(int direction) {
    final session = ref.read(playbackSessionProvider);
    final channels = session.channelList;
    if (channels == null || channels.length <= 1) return;

    final idx = (session.channelIndex + direction) % channels.length;
    _zapToChannelAt(channels[idx], index: idx);
  }

  /// Zap directly to [ch] by resolving its index from the session list.
  void _zapToChannel(Channel ch) {
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

    _activeStreamUrl = ch.streamUrl;
    _showZapNameBriefly(ch.name);
    ref.read(favoritesHistoryProvider.notifier).addToHistory(ch);
  }

  void _showZapNameBriefly(String name) {
    _zapOverlayTimer?.cancel();
    setState(() => _zapChannelName = name);
    _zapOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _zapChannelName = null);
    });
  }

  // ────────────────────────────────────────────────
  //  Tap handler
  // ────────────────────────────────────────────────

  void _onTap() {
    if (isInPip) {
      if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
        pipHandler.exitPiP().then((_) {
          if (mounted) setState(() => isInPip = false);
        });
      }
    } else {
      ref.read(osdStateProvider.notifier).toggle();
    }
  }

  // ────────────────────────────────────────────────
  //  Keyboard
  // ────────────────────────────────────────────────

  void _onKeyEvent(KeyEvent event) {
    final session = ref.read(playbackSessionProvider);
    final canZap =
        session.isLive &&
        session.channelList != null &&
        session.channelList!.length > 1;

    handlePlayerKeyEvent(
      event: event,
      ref: ref,
      isLive: session.isLive,
      canZap: canZap,
      hasPrimaryFocus: _focusNode.hasPrimaryFocus,
      showZapOverlay: _showZapOverlay,
      onPlayPause: () => ref.read(playerServiceProvider).playOrPause(),
      onZapChannel: _zapChannel,
      onSeekForward: () {
        final svc = ref.read(playerServiceProvider);
        final step = Duration(seconds: ref.read(seekStepSecondsProvider));
        svc.seek(svc.state.position + step);
        showSeekIndicator(true);
      },
      onSeekBack: () {
        final svc = ref.read(playerServiceProvider);
        final step = Duration(seconds: ref.read(seekStepSecondsProvider));
        final p = svc.state.position - step;
        svc.seek(p < Duration.zero ? Duration.zero : p);
        showSeekIndicator(false);
      },
      onToggleFullscreen: toggleOsFullscreen,
      onToggleZap: () => setState(() => _showZapOverlay = !_showZapOverlay),
      onShowZap: () => setState(() => _showZapOverlay = true),
      onBack: onBack,
      onToggleCaptions: () {
        final state = ref.read(playbackStateProvider).value;
        if (state != null) {
          showSubtitleTrackPicker(context, ref, state);
        }
      },
      onShowShortcuts: () {
        setState(() => _showShortcutsHelp = !_showShortcutsHelp);
      },
      onToggleLock: () {
        ref.read(playerLockedProvider.notifier).toggle();
      },
    );
  }

  // ────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Activate setting-sync side-effect providers.
    ref.watch(hwdecSyncProvider);
    ref.watch(audioSyncProvider);
    ref.watch(upscaleSyncProvider);
    ref.watch(deinterlaceSyncProvider);

    // React to player mode changes → apply SystemChrome as a side
    // effect via ref.listen (never inline in build).
    ref.listen(playerModeProvider.select((s) => s.mode), (prev, next) {
      if (next != _lastAppliedMode) {
        _lastAppliedMode = next;
        _applySystemChrome(next);
      }
    });

    // Detect session changes (new stream started).
    ref.listen(playbackSessionProvider.select((s) => s.streamUrl), (
      prev,
      next,
    ) {
      if (next.isNotEmpty && next != _activeStreamUrl) {
        _syncSession();
      }
    });

    final session = ref.watch(playbackSessionProvider);

    final s = ref.watch(
      playbackStateProvider.select(
        (a) => a.when(
          data:
              (s) => (
                status: s.status,
                isTrulyLive: s.isLive || s.duration == Duration.zero,
                errorMessage: s.errorMessage,
                isBuffering: s.isBuffering,
                hasError: s.hasError,
                retryCount: s.retryCount,
                channelLogoUrl: s.channelLogoUrl,
              ),
          loading:
              () => (
                status: PlaybackStatus.buffering,
                isTrulyLive: false,
                errorMessage: null as String?,
                isBuffering: true,
                hasError: false,
                retryCount: 0,
                channelLogoUrl: null as String?,
              ),
          error:
              (e, _) => (
                status: PlaybackStatus.error,
                isTrulyLive: false,
                errorMessage: e.toString(),
                isBuffering: false,
                hasError: true,
                retryCount: 0,
                channelLogoUrl: null as String?,
              ),
        ),
      ),
    );

    final isLiveStream = s.isTrulyLive;
    final canZap =
        session.isLive &&
        session.channelList != null &&
        session.channelList!.length > 1;

    final seekStep = ref.watch(seekStepSecondsProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        PlayerMouseRegion(
          child: Listener(
            onPointerSignal: (e) => onPointerSignal(e, isInPip),
            onPointerDown: (e) => lastPointerKind = e.kind,
            child: KeyboardListener(
              focusNode: _focusNode,
              onKeyEvent: _onKeyEvent,
              child: GestureDetector(
                key: TestKeys.playerGestureDetector,
                onTap: _onTap,
                onDoubleTapDown:
                    isInPip
                        ? null
                        : (details) {
                          if (lastPointerKind == PointerDeviceKind.mouse) {
                            // Mouse double-click → fullscreen toggle.
                            if (PlatformCapabilities.fullscreen) {
                              toggleOsFullscreen();
                            }
                          } else if (!isLiveStream) {
                            // Touch double-tap → seek (VOD only).
                            // FE-PS-19: resets zoom first if zoomed.
                            onDoubleTapDown(details);
                          }
                        },
                onDoubleTap: isInPip ? null : () {},
                onLongPressStart:
                    isLiveStream || isInPip ? null : onLongPressStart,
                onLongPressMoveUpdate:
                    isLiveStream || isInPip ? null : onLongPressMoveUpdate,
                onLongPressEnd: isLiveStream || isInPip ? null : onLongPressEnd,
                onVerticalDragStart: isInPip ? null : onSwipeStart,
                onVerticalDragUpdate: onSwipeUpdate,
                onVerticalDragEnd: (_) {
                  isSwiping = false;
                  swipeType = null;
                },
                // FE-PS-19: Pinch-to-zoom — scale gestures.
                onScaleStart: isInPip ? null : onScaleStart,
                onScaleUpdate: isInPip ? null : onScaleUpdate,
                onScaleEnd: isInPip ? null : onScaleEnd,
                behavior: HitTestBehavior.opaque,
                child: PlayerStack(
                  // Transparent placeholder — video is in
                  // PermanentVideoLayer on the Stack layer below.
                  videoSurface: const SizedBox.shrink(),
                  seekStepSeconds: seekStep,
                  brightnessNotifier: brightnessNotifier,
                  isInPip: isInPip,
                  isBuffering: s.isBuffering,
                  retryCount: s.retryCount,
                  seekDirection: seekDirection,
                  hasError: s.hasError,
                  errorMessage: s.errorMessage,
                  onRetry: () => ref.read(playerServiceProvider).retry(),
                  isSwiping: isSwiping,
                  swipeType: swipeType,
                  swipeValue:
                      swipeType == SwipeType.volume
                          ? ref.read(playerServiceProvider).state.volume
                          : 1.0 - brightnessNotifier.value,
                  zapChannelName: _zapChannelName,
                  canZap: canZap,
                  showZapOverlay: _showZapOverlay,
                  rightEdgeThreshold: PlayerGestureMixin.rightEdgeThreshold,
                  onSwipeLeftEdge: () => setState(() => _showZapOverlay = true),
                  isLive: session.isLive,
                  channelList: session.channelList,
                  currentChannelIndex: session.channelIndex,
                  onZapDismiss: () => setState(() => _showZapOverlay = false),
                  onChannelSelected: (ch) {
                    _zapToChannel(ch);
                    setState(() => _showZapOverlay = false);
                  },
                  nextEpisode: nextEpisodeToShow,
                  onPlayNext:
                      nextEpisodeToShow != null
                          ? () => playNextEpisode(nextEpisodeToShow!)
                          : null,
                  onCancelNext: () => setState(() => nextEpisodeToShow = null),
                  showMovieCompletion: showMovieCompletion,
                  currentTitle: session.channelName,
                  onWatchAgain:
                      showMovieCompletion
                          ? () {
                            setState(() => showMovieCompletion = false);
                            ref.read(playerServiceProvider).seek(Duration.zero);
                            ref.read(playerServiceProvider).playOrPause();
                          }
                          : null,
                  onBrowseMore:
                      showMovieCompletion
                          ? () {
                            setState(() => showMovieCompletion = false);
                            onBack();
                          }
                          : null,
                  streamUrl: session.streamUrl,
                  onBack: onBack,
                  onToggleFullscreen:
                      PlatformCapabilities.fullscreen
                          ? () => toggleOsFullscreen()
                          : null,
                  onEnterPip: PlatformCapabilities.pip ? onEnterPip : null,
                  onToggleZapOverlay:
                      canZap
                          ? () =>
                              setState(() => _showZapOverlay = !_showZapOverlay)
                          : null,
                  onOpenExternal:
                      PlatformCapabilities.externalPlayer
                          ? () => launchExternalPlayer(
                            ref: ref,
                            context: context,
                            streamUrl: session.streamUrl,
                            mounted: mounted,
                            title: session.channelName,
                            headers: session.headers,
                          )
                          : null,
                  channelLogoUrl: s.channelLogoUrl,
                ),
              ),
            ),
          ),
        ),

        // ── Shortcuts help overlay (? key) ──
        if (_showShortcutsHelp && !isInPip)
          PlayerShortcutsHelpOverlay(
            onDismiss: () => setState(() => _showShortcutsHelp = false),
          ),

        // FE-PS-19: Zoom percentage indicator (pinch-to-zoom HUD).
        if (!isInPip && (zoomScale != 1.0 || isPinching))
          _ZoomIndicatorOverlay(label: zoomPercentLabel, visible: isPinching),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FE-PS-19: Zoom percentage HUD overlay
// ─────────────────────────────────────────────────────────────

/// Centered glassmorphic badge showing the current zoom level.
///
/// Shown while pinching and briefly after the gesture ends.
/// Fades when [visible] is false (gesture ended).
class _ZoomIndicatorOverlay extends StatelessWidget {
  const _ZoomIndicatorOverlay({required this.label, required this.visible});

  final String label;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.center,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.6,
        duration: CrispyAnimation.osdShow,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(CrispyRadius.sm),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.15)),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
