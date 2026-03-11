import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/utils/fullscreen_helper.dart';
import '../providers/pip_provider.dart';
import '../providers/player_providers.dart';
import 'player_fullscreen_overlay.dart';

/// App-lifecycle and window-focus handling mixin for
/// [PlayerFullscreenOverlay].
///
/// Owns PiP state, auto-pause-on-background, desktop window
/// focus/blur, OS fullscreen sync, and the back/PiP action
/// callbacks.
mixin PlayerLifecycleMixin on ConsumerState<PlayerFullscreenOverlay> {
  /// Override to restore keyboard focus after lifecycle events
  /// that may steal it (fullscreen toggle, window restore).
  void restorePlayerFocus();

  // ── Lifecycle state ──
  bool autoPausedByLifecycle = false;
  bool autoPausedByFocusLoss = false;
  bool isWindowListenerRegistered = false;
  bool isInPip = false;
  VoidCallback? cancelFullscreenListener;
  bool _wasMaximizedBeforeFullscreen = false;
  Offset? _windowPosBeforeFullscreen;
  Size? _windowSizeBeforeFullscreen;

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
    final pipNotifier = ref.read(pipProvider.notifier);
    final pipState = ref.read(pipProvider);

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      final settings = ref.read(settingsNotifierProvider).asData?.value;
      final pipOnMinimize = settings?.config.player.pipOnMinimize ?? true;

      if (pipOnMinimize && !pipState.isActive) {
        pipNotifier.enterPip().then((result) {
          final (entered, _) = result;
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
        // AND-07: Don't pause video when entering PiP mode on
        // Android — onPause fires during PiP transition.
        if (!isInPip && playerService.state.isPlaying) {
          autoPausedByLifecycle = true;
          playerService.pause();
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (isInPip) {
        pipNotifier.exitPip();
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
    restorePlayerFocus();
  }

  Future<void> toggleOsFullscreen() async {
    if (kIsWeb) {
      toggleWebFullscreen();
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final isFs = await windowManager.isFullScreen();
      if (!isFs) {
        // Remember window state before entering fullscreen.
        _wasMaximizedBeforeFullscreen = await windowManager.isMaximized();
        if (!_wasMaximizedBeforeFullscreen) {
          _windowPosBeforeFullscreen = await windowManager.getPosition();
          _windowSizeBeforeFullscreen = await windowManager.getSize();
        }
        // Un-maximize first — Windows cannot transition
        // directly from maximized to true fullscreen.
        if (_wasMaximizedBeforeFullscreen) {
          await windowManager.unmaximize();
          // WIN-01: Poll until window actually un-maximizes.
          // PostMessage(WM_SYSCOMMAND, SC_RESTORE) is async —
          // Dart await resolves before the window restores.
          for (var i = 0; i < 20; i++) {
            if (!await windowManager.isMaximized()) break;
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
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
    restorePlayerFocus();
  }

  /// Restore window state after leaving fullscreen.
  /// Called from [onWindowLeaveFullScreen] to cover both
  /// the toggle button and OS-level exit (e.g. Esc key).
  Future<void> restoreWindowState() async {
    if (_wasMaximizedBeforeFullscreen) {
      _wasMaximizedBeforeFullscreen = false;
      _windowPosBeforeFullscreen = null;
      _windowSizeBeforeFullscreen = null;
      await windowManager.maximize();
    } else if (_windowSizeBeforeFullscreen != null) {
      final size = _windowSizeBeforeFullscreen!;
      final pos = _windowPosBeforeFullscreen;
      _windowSizeBeforeFullscreen = null;
      _windowPosBeforeFullscreen = null;
      await windowManager.setSize(size);
      if (pos != null) {
        await windowManager.setPosition(pos);
      }
    }
  }

  void onBack() {
    // If in OS fullscreen, exit it before closing the player
    // so the window restores smoothly (title bar reappears).
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.isFullScreen().then((isFs) {
        if (isFs) {
          windowManager.setFullScreen(false).then((_) {
            restoreWindowState();
            if (mounted) _doExitToPreview();
          });
          return;
        }
        if (mounted) _doExitToPreview();
      });
      return;
    }
    _doExitToPreview();
  }

  void _doExitToPreview() {
    final screenSize = MediaQuery.sizeOf(context);
    ref.read(playerModeProvider.notifier).exitToPreview(screenSize: screenSize);
    ref.read(playerServiceProvider).forceStateEmit();
  }

  void onEnterPip() {
    ref.read(pipProvider.notifier).enterPip().then((result) {
      final (ok, _) = result;
      if (ok && mounted) {
        setState(() => isInPip = true);
      }
    });
  }

  /// Arm native auto-PiP for seamless background entry.
  ///
  /// On Android API 31+, `setAutoEnterEnabled(true)` makes the
  /// OS auto-enter PiP on home press. On older Android, the
  /// `onUserLeaveHint()` Kotlin callback handles it.
  /// Call from [initState] when player starts and from
  /// [dispose] to disarm.
  void armAutoPip() {
    final settings = ref.read(settingsNotifierProvider).asData?.value;
    final pipOnMinimize = settings?.config.player.pipOnMinimize ?? true;
    if (pipOnMinimize) {
      ref.read(pipProvider.notifier).setAutoPipReady(ready: true);
    }
  }

  /// Disarm native auto-PiP.
  void disarmAutoPip() {
    ref.read(pipProvider.notifier).setAutoPipReady(ready: false);
  }
}
