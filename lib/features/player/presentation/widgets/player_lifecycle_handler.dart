import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/utils/fullscreen_helper.dart';
import '../../../../core/utils/pip_handler.dart';
import '../providers/player_providers.dart';
import 'player_fullscreen_overlay.dart';

/// App-lifecycle and window-focus handling mixin for
/// [PlayerFullscreenOverlay].
///
/// Owns PiP state, auto-pause-on-background, desktop window
/// focus/blur, OS fullscreen sync, and the back/PiP action
/// callbacks.
mixin PlayerLifecycleMixin on ConsumerState<PlayerFullscreenOverlay> {
  // ── Lifecycle state ──
  bool autoPausedByLifecycle = false;
  bool autoPausedByFocusLoss = false;
  bool isWindowListenerRegistered = false;
  final pipHandler = PipHandler();
  bool isInPip = false;
  VoidCallback? cancelFullscreenListener;
  bool _wasMaximizedBeforeFullscreen = false;

  /// Call from [initState] on the state that also mixes in
  /// [WindowListener].  Registers the window listener when on a
  /// desktop platform and sets up the web fullscreen change callback.
  void initWindowListener() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.addListener(this as WindowListener);
      isWindowListenerRegistered = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final isFs = await windowManager.isFullScreen();
        if (mounted) {
          ref.read(playerServiceProvider).setFullscreen(isFs);
        }
      });
    }
  }

  void initFullscreenSync() {
    cancelFullscreenListener = onWebFullscreenChange((isFullscreen) {
      if (mounted) {
        ref.read(playerServiceProvider).setFullscreen(isFullscreen);
      }
    });

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(playerServiceProvider).setFullscreen(isWebFullscreen());
        }
      });
    }
  }

  void handleAppLifecycleChange(AppLifecycleState state) {
    final playerService = ref.read(playerServiceProvider);

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      final settings = ref.read(settingsNotifierProvider).asData?.value;
      final pipOnMinimize = settings?.config.player.pipOnMinimize ?? true;

      if (pipOnMinimize && !pipHandler.isPipMode && !kIsWeb) {
        pipHandler.enterPiP().then((entered) {
          if (entered && mounted) {
            setState(() => isInPip = true);
          } else if (mounted) {
            if (playerService.state.isPlaying) {
              autoPausedByLifecycle = true;
              playerService.pause();
            }
          }
        });
      } else {
        if (playerService.state.isPlaying) {
          autoPausedByLifecycle = true;
          playerService.pause();
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (isInPip) {
        setState(() => isInPip = false);
      }
      if (autoPausedByLifecycle) {
        autoPausedByLifecycle = false;
        playerService.resume();
      }
      playerService.resumeFromWatchdog();
    }
  }

  void handleWindowBlur() {
    final settings = ref.read(settingsNotifierProvider).asData?.value;
    final pauseOnFocusLoss = settings?.config.player.pauseOnFocusLoss ?? false;

    if (pauseOnFocusLoss) {
      final service = ref.read(playerServiceProvider);
      if (service.state.isPlaying) {
        autoPausedByFocusLoss = true;
        service.pause();
      }
    }
  }

  void handleWindowFocus() {
    if (autoPausedByFocusLoss) {
      autoPausedByFocusLoss = false;
      ref.read(playerServiceProvider).resume();
    }
    ref.read(playerServiceProvider).resumeFromWatchdog();
  }

  Future<void> toggleOsFullscreen() async {
    if (kIsWeb) {
      toggleWebFullscreen();
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final isFs = await windowManager.isFullScreen();
      if (!isFs) {
        // Remember maximized state before entering fullscreen.
        _wasMaximizedBeforeFullscreen = await windowManager.isMaximized();
        // Un-maximize first — Windows cannot transition
        // directly from maximized to true fullscreen.
        if (_wasMaximizedBeforeFullscreen) await windowManager.unmaximize();
      }
      await windowManager.setFullScreen(!isFs);
    } else {
      final service = ref.read(playerServiceProvider);
      final isFullscreen = !service.state.isFullscreen;
      service.setFullscreen(isFullscreen);
      SystemChrome.setEnabledSystemUIMode(
        isFullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }
  }

  /// Restore maximized state after leaving fullscreen.
  /// Called from [onWindowLeaveFullScreen] to cover both
  /// the toggle button and OS-level exit (e.g. Esc key).
  Future<void> restoreMaximizedState() async {
    if (_wasMaximizedBeforeFullscreen) {
      _wasMaximizedBeforeFullscreen = false;
      await windowManager.maximize();
    }
  }

  void onBack() {
    ref.read(playerModeProvider.notifier).exitToPreview();
    ref.read(playerServiceProvider).forceStateEmit();
  }

  void onEnterPip() {
    pipHandler.enterPiP().then((ok) {
      if (ok && mounted) {
        setState(() => isInPip = true);
      }
    });
  }
}
