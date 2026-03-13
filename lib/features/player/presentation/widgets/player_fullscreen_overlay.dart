import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/data/cache_service.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../../core/utils/screen_brightness_helper.dart';
import '../../../favorites/data/favorites_history_service.dart';
import '../providers/pip_provider.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../data/shader_service.dart';
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
import 'player_osd/subtitle_style_dialog.dart';
import 'player_queue_overlay.dart';
import 'player_shortcuts_help_overlay.dart';
import 'player_guide_split.dart';
import 'player_stack.dart';
import 'screensaver_overlay.dart';
import 'player_zoom_indicator.dart';
import 'screenshot_indicator.dart';

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

  /// Whether the video expand animation has completed.
  /// OSD content delays rendering until this is true.
  bool _isVideoExpanded = false;

  // ── Mouse double-click detection ──
  // Flutter's gesture arena uses a 300ms double-tap timeout,
  // shorter than typical desktop double-click speed (400–500ms).
  // Manual detection in Listener.onPointerDown bypasses the
  // arena for reliable mouse double-click → fullscreen toggle.
  DateTime? _lastMouseDownTime;
  Offset? _lastMouseDownPos;
  Timer? _singleClickTimer;
  DateTime? _lastDoubleClickTime;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addObserver(this);
    initWindowListener();
    initFullscreenSync();
    FocusManager.instance.addLateKeyEventHandler(_lateKeyHandler);

    // Defer initial playback setup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncSession();
        _focusNode.requestFocus();
        // Apply initial SystemChrome state after first frame.
        final mode = ref.read(playerModeProvider).mode;
        _applySystemChrome(mode);
        _lastAppliedMode = mode;
        // Apply persisted subtitle style to mpv.
        try {
          final style = ref.read(subtitleStyleProvider);
          final player = ref.read(playerProvider);
          applySubtitleStyleToPlayer(player, style);
        } catch (_) {}
      }
    });

    // Delay OSD rendering until the video expand animation completes
    // (CrispyAnimation.normal = 300ms). During this time the video is
    // animating from preview/mini to fullscreen beneath this overlay.
    Future.delayed(CrispyAnimation.normal, () {
      if (mounted) setState(() => _isVideoExpanded = true);
    });

    // Arm native auto-PiP so the OS enters PiP on home press
    // (Android API 31+ setAutoEnterEnabled, API 26-30 onUserLeaveHint).
    armAutoPip();
  }

  /// Applies [SystemChrome] immersive/orientation settings for the
  /// given [mode] on mobile platforms. Respects the user's saved
  /// rotation lock preference when in fullscreen. Must be called
  /// from lifecycle hooks — never from [build].
  Future<void> _applySystemChrome(PlayerMode mode) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (mode == PlayerMode.fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final orientations = await _loadRotationLock();
      SystemChrome.setPreferredOrientations(orientations.toList());
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

  /// Reads the persisted rotation lock preference. Falls back to
  /// landscape-only when no preference has been saved.
  Future<List<DeviceOrientation>> _loadRotationLock() async {
    final json = await ref
        .read(cacheServiceProvider)
        .getSetting(kRotationLockKey);
    if (json == null || json.isEmpty) {
      return [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
    }
    final indices = (jsonDecode(json) as List).cast<int>();
    return indices.map((i) => DeviceOrientation.values[i]).toList();
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
    // OS fullscreen state tracked via PlayerMode, not PlaybackState.
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) {
      restoreWindowState();
    }
  }

  @override
  void dispose() {
    disarmAutoPip();
    cancelFullscreenListener?.call();
    WidgetsBinding.instance.removeObserver(this);
    if (isWindowListenerRegistered) {
      windowManager.removeListener(this);
      // Exit OS fullscreen when overlay unmounts — the player is
      // no longer visible so the window should restore its frame.
      windowManager.isFullScreen().then((isFs) {
        if (isFs) {
          windowManager.setFullScreen(false).then((_) {
            restoreWindowState();
          });
        }
      });
    }
    if (isInPip) ref.read(pipProvider.notifier).exitPip();

    // Restore all orientations on player exit (REQ-05).
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setPreferredOrientations([]);
    }

    // Reset screen brightness to system default on player exit (REQ-04).
    if (ref.read(screenBrightnessProvider) != null) {
      ref.read(screenBrightnessProvider.notifier).resetToSystem();
      ScreenBrightnessHelper.resetBrightness();
    }

    // Reset always-on-top on player exit.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      if (ref.read(alwaysOnTopProvider)) {
        ref.read(alwaysOnTopProvider.notifier).set(false);
        windowManager.setAlwaysOnTop(false);
      }
    }

    _zapOverlayTimer?.cancel();
    _singleClickTimer?.cancel();
    FocusManager.instance.removeLateKeyEventHandler(_lateKeyHandler);
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

    // Skip full sync if this stream was already synced — happens when
    // the overlay is remounted after a mini-player ↔ fullscreen toggle.
    final lastSynced = ref.read(lastSyncedStreamUrlProvider);
    if (session.streamUrl == lastSynced) {
      _activeStreamUrl = session.streamUrl;
      return;
    }

    if (session.streamUrl == _activeStreamUrl) return;

    _activeStreamUrl = session.streamUrl;
    ref.read(lastSyncedStreamUrlProvider.notifier).set(session.streamUrl);
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
  //  Queue item playback
  // ────────────────────────────────────────────────

  /// Plays a queue item based on the current session type.
  void _playQueueItem(QueueItem item, PlaybackSessionState session) {
    // Hide the queue panel.
    ref.read(queueProvider.notifier).hide();

    if (session.isLive) {
      // Live TV: find the Channel in the list and zap to it.
      final ch = session.channelList?.firstWhere(
        (c) => c.id == item.id,
        orElse:
            () => Channel(
              id: item.id,
              name: item.title,
              streamUrl: item.streamUrl,
            ),
      );
      if (ch != null) _zapToChannel(ch);
    } else {
      // VOD: find the episode in the list and play it.
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

  // ────────────────────────────────────────────────
  //  Mouse double-click detection
  // ────────────────────────────────────────────────

  /// Detects mouse double-clicks with a 400ms window.
  ///
  /// Flutter's [kDoubleTapTimeout] is 300ms — shorter than the
  /// typical desktop double-click speed (400–500ms). Detecting
  /// directly in [Listener.onPointerDown] bypasses the gesture
  /// arena for reliable mouse double-click → fullscreen toggle.
  void _handlePointerDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse) return;

    final now = DateTime.now();
    final pos = e.position;

    if (_lastMouseDownTime != null &&
        _lastMouseDownPos != null &&
        now.difference(_lastMouseDownTime!) <
            const Duration(milliseconds: 400) &&
        (pos - _lastMouseDownPos!).distance < 20.0) {
      // Double-click detected.
      _lastMouseDownTime = null;
      _lastMouseDownPos = null;
      _singleClickTimer?.cancel();
      _singleClickTimer = null;
      _lastDoubleClickTime = now;
      if (!isInPip && PlatformCapabilities.fullscreen) {
        // Defer to next frame — calling windowManager.setFullScreen()
        // during a pointer event handler conflicts with the native
        // Windows message loop, leaving the title bar visible.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) toggleOsFullscreen();
        });
      }
    } else {
      _lastMouseDownTime = now;
      _lastMouseDownPos = pos;
    }
  }

  // ────────────────────────────────────────────────
  //  Tap handler
  // ────────────────────────────────────────────────

  void _onTap() {
    if (isInPip) {
      if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
        ref.read(pipProvider.notifier).exitPip().then((_) {
          if (mounted) setState(() => isInPip = false);
        });
      }
    } else {
      ref.read(playerServiceProvider).playOrPause();
      ref.read(osdStateProvider.notifier).show();
    }
    _restoreFocus();
  }

  // ────────────────────────────────────────────────
  //  Focus management
  // ────────────────────────────────────────────────

  /// Late key event handler — fires only for events NOT consumed
  /// by any widget in the focus tree. Acts as a safety net when
  /// focus is lost (e.g. after mouse clicks steal focus).
  /// Restores focus to [_focusNode] so subsequent key events are
  /// handled by [KeyboardListener.onKeyEvent] directly.
  KeyEventResult _lateKeyHandler(KeyEvent event) {
    if (!mounted) return KeyEventResult.ignored;
    if (ModalRoute.of(context)?.isCurrent != true) {
      return KeyEventResult.ignored;
    }
    // Restore focus so primary handler takes over next time.
    if (!_focusNode.hasPrimaryFocus) {
      _focusNode.requestFocus();
    }
    _onKeyEvent(event);
    return KeyEventResult.handled;
  }

  /// Restores keyboard focus to the player's [_focusNode].
  void _restoreFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasPrimaryFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void restorePlayerFocus() => _restoreFocus();

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
      // Always true: the late key handler only fires for events
      // not consumed by any focused widget, so button activation
      // keys (Enter/Space) are already handled upstream.
      hasPrimaryFocus: true,
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
      onOpenGuide: () {
        ref.read(guideSplitProvider.notifier).toggle();
      },
      onShowDebug: () {
        ref.read(streamStatsVisibleProvider.notifier).update((v) => !v);
      },
      onScreenshot: () {
        captureScreenshot(boundaryKey: screenshotBoundaryKey, ref: ref);
      },
      onCleanScreenshot: () {
        captureScreenshot(
          boundaryKey: screenshotBoundaryKey,
          ref: ref,
          clean: true,
        );
      },
      onAlwaysOnTop: () {
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
          final notifier = ref.read(alwaysOnTopProvider.notifier);
          notifier.toggle();
          final newValue = ref.read(alwaysOnTopProvider);
          windowManager.setAlwaysOnTop(newValue);
        }
      },
      onCycleShader: () {
        final current = ref.read(shaderPresetProvider);
        final presets = ShaderPreset.allPresets;
        final idx = presets.indexWhere((p) => p.id == current.id);
        final next = presets[(idx + 1) % presets.length];
        ref.read(settingsNotifierProvider.notifier).setShaderPreset(next.id);
      },
    );
  }

  // ────────────────────────────────────────────────
  //  Build
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // During the initial video expand animation, render nothing —
    // the video is animating beneath and OSD would flash prematurely.
    if (!_isVideoExpanded) return const SizedBox.expand();

    // Activate setting-sync side-effect providers.
    ref.watch(hwdecSyncProvider);
    ref.watch(audioSyncProvider);
    ref.watch(upscaleSyncProvider);
    ref.watch(deinterlaceSyncProvider);
    ref.watch(streamProfileSyncProvider);
    ref.watch(queueAutoPopulateProvider);

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

    // Restore focus when OSD finishes hiding — ExcludeFocus ejects
    // OSD buttons from the focus tree, scattering focus.
    ref.listen(osdStateProvider, (prev, next) {
      if (next == OsdState.hidden && prev != null && prev != OsdState.hidden) {
        _restoreFocus();
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
            onPointerDown: (e) {
              lastPointerKind = e.kind;
              _handlePointerDown(e);
            },
            child: Focus(
              focusNode: _focusNode,
              onKeyEvent: (_, event) {
                _onKeyEvent(event);
                return KeyEventResult.handled;
              },
              child: GestureDetector(
                key: TestKeys.playerGestureDetector,
                onTap: () {
                  if (lastPointerKind == PointerDeviceKind.mouse) {
                    // Suppress taps following a mouse double-click.
                    if (_lastDoubleClickTime != null &&
                        DateTime.now().difference(_lastDoubleClickTime!) <
                            const Duration(milliseconds: 800)) {
                      return;
                    }
                    // Delay mouse tap to allow double-click detection
                    // (400ms vs Flutter's 300ms double-tap timeout).
                    _singleClickTimer?.cancel();
                    _singleClickTimer = Timer(
                      const Duration(milliseconds: 400),
                      () {
                        _singleClickTimer = null;
                        _onTap();
                      },
                    );
                  } else {
                    _onTap();
                  }
                },
                onDoubleTapDown:
                    isInPip
                        ? null
                        : (details) {
                          // Mouse double-click handled via
                          // Listener.onPointerDown for reliable
                          // timing (400ms vs Flutter's 300ms).
                          // Touch double-tap → seek (VOD only).
                          if (lastPointerKind != PointerDeviceKind.mouse &&
                              !isLiveStream) {
                            onDoubleTapDown(details);
                          }
                        },
                onDoubleTap: isInPip ? null : () {},
                onLongPressStart:
                    isLiveStream || isInPip ? null : onLongPressStart,
                onLongPressMoveUpdate:
                    isLiveStream || isInPip ? null : onLongPressMoveUpdate,
                onLongPressEnd: isLiveStream || isInPip ? null : onLongPressEnd,
                // WIN-05: In PiP on desktop, drag to move the
                // frameless window. startDragging() hands off
                // to the OS so horizontal movement also works.
                onVerticalDragStart:
                    isInPip
                        ? (!kIsWeb &&
                                (Platform.isWindows ||
                                    Platform.isLinux ||
                                    Platform.isMacOS)
                            ? (_) => windowManager.startDragging()
                            : null)
                        : onSwipeStart,
                onVerticalDragUpdate: isInPip ? null : onSwipeUpdate,
                onVerticalDragEnd:
                    isInPip
                        ? null
                        : (_) {
                          isSwiping = false;
                          swipeType = null;
                        },
                // FE-PS-19: Pinch-to-zoom — scale gestures.
                onScaleStart: isInPip ? null : onScaleStart,
                onScaleUpdate: isInPip ? null : onScaleUpdate,
                onScaleEnd: isInPip ? null : onScaleEnd,
                behavior: HitTestBehavior.opaque,
                child: ScreensaverController(
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
                    onSwipeLeftEdge:
                        () => setState(() => _showZapOverlay = true),
                    isLive: session.isLive,
                    channelList: session.channelList,
                    currentChannelIndex: session.channelIndex,
                    onZapDismiss: () {
                      setState(() => _showZapOverlay = false);
                      _restoreFocus();
                    },
                    onChannelSelected: (ch) {
                      _zapToChannel(ch);
                      setState(() => _showZapOverlay = false);
                      _restoreFocus();
                    },
                    nextEpisode: nextEpisodeToShow,
                    onPlayNext:
                        nextEpisodeToShow != null
                            ? () => playNextEpisode(nextEpisodeToShow!)
                            : null,
                    onCancelNext:
                        () => setState(() => nextEpisodeToShow = null),
                    showMovieCompletion: showMovieCompletion,
                    currentTitle: session.channelName,
                    onWatchAgain:
                        showMovieCompletion
                            ? () {
                              setState(() => showMovieCompletion = false);
                              ref
                                  .read(playerServiceProvider)
                                  .seek(Duration.zero);
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
                            ? () => setState(
                              () => _showZapOverlay = !_showZapOverlay,
                            )
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
                    onSkipToQueueItem: (item) => _playQueueItem(item, session),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Shortcuts help overlay (? key) ──
        if (_showShortcutsHelp && !isInPip)
          PlayerShortcutsHelpOverlay(
            onDismiss: () {
              setState(() => _showShortcutsHelp = false);
              _restoreFocus();
            },
          ),

        // FE-PS-19: Zoom percentage indicator (pinch-to-zoom HUD).
        if (!isInPip && (zoomScale != 1.0 || isPinching))
          PlayerZoomIndicator(label: zoomPercentLabel, visible: isPinching),

        // TV guide split-screen — EPG grid on the right half.
        if (!isInPip)
          Consumer(
            builder: (context, ref, _) {
              final guideSplit = ref.watch(guideSplitProvider);
              if (!guideSplit) return const SizedBox.shrink();
              final screenWidth = MediaQuery.sizeOf(context).width;

              return Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: screenWidth / 2,
                child: PlayerGuideSplit(
                  onChannelSelected: (ch) {
                    _zapToChannel(ch);
                    _restoreFocus();
                  },
                  onDismiss: () {
                    ref.read(guideSplitProvider.notifier).set(value: false);
                    _restoreFocus();
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
