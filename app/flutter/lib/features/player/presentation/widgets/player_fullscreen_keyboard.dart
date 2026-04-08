import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/utils/keyboard_utils.dart';
import '../providers/player_providers.dart';
import '../screens/player_keyboard_handler.dart';
import 'player_fullscreen_overlay.dart';
import 'player_fullscreen_zap.dart';
import 'player_history_tracker.dart';
import 'player_osd/osd_subtitle_picker.dart';
import 'screenshot_indicator.dart';

/// Keyboard and focus management for [PlayerFullscreenOverlay].
///
/// Applied after [PlayerFullscreenZapMixin] so [showZapOverlay] and
/// [zapChannel] resolve from that mixin's fields.
mixin PlayerFullscreenKeyboardMixin
    on
        ConsumerState<PlayerFullscreenOverlay>,
        PlayerHistoryMixin,
        PlayerFullscreenZapMixin {
  // ── Abstract cross-mixin interface ───────────────────────────
  // Provided by PlayerLifecycleMixin — declared here so the mixin
  // compiles; resolved at linearization time.
  Future<void> toggleOsFullscreen();
  void onBack();

  // Provided by PlayerGestureMixin.
  void showSeekIndicator(bool forward);

  // ── Shortcuts help state (owned here, surfaced to build) ─────
  bool showShortcutsHelp = false;

  // ────────────────────────────────────────────────
  //  Late key event handler
  // ────────────────────────────────────────────────

  /// Late key event handler — fires only for events NOT consumed
  /// by any widget in the focus tree. Acts as a safety net when
  /// focus is lost (e.g. after mouse clicks steal focus).
  KeyEventResult lateKeyHandler(FocusNode focusNode, KeyEvent event) {
    if (!mounted) return KeyEventResult.ignored;
    if (ModalRoute.of(context)?.isCurrent != true) {
      return KeyEventResult.ignored;
    }

    if (isTextFieldFocused() && _isTextInputKey(event)) {
      return KeyEventResult.ignored;
    }

    if (!focusNode.hasPrimaryFocus) {
      focusNode.requestFocus();
    }
    onKeyEvent(event);
    return KeyEventResult.handled;
  }

  /// Returns `true` for keys that produce text input — letters,
  /// digits, and printable symbols.
  static bool _isTextInputKey(KeyEvent event) {
    final key = event.logicalKey;
    final keyId = key.keyId;

    if (keyId >= 0x00000061 && keyId <= 0x0000007A) return true;
    if (keyId >= 0x00000030 && keyId <= 0x00000039) return true;

    if (key == LogicalKeyboardKey.numpad0 ||
        key == LogicalKeyboardKey.numpad1 ||
        key == LogicalKeyboardKey.numpad2 ||
        key == LogicalKeyboardKey.numpad3 ||
        key == LogicalKeyboardKey.numpad4 ||
        key == LogicalKeyboardKey.numpad5 ||
        key == LogicalKeyboardKey.numpad6 ||
        key == LogicalKeyboardKey.numpad7 ||
        key == LogicalKeyboardKey.numpad8 ||
        key == LogicalKeyboardKey.numpad9) {
      return true;
    }

    if (key == LogicalKeyboardKey.slash ||
        key == LogicalKeyboardKey.backslash ||
        key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.comma ||
        key == LogicalKeyboardKey.semicolon ||
        key == LogicalKeyboardKey.quoteSingle ||
        key == LogicalKeyboardKey.quote ||
        key == LogicalKeyboardKey.bracketLeft ||
        key == LogicalKeyboardKey.bracketRight ||
        key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.backquote ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.at ||
        key == LogicalKeyboardKey.colon ||
        key == LogicalKeyboardKey.underscore ||
        key == LogicalKeyboardKey.exclamation ||
        key == LogicalKeyboardKey.numberSign ||
        key == LogicalKeyboardKey.dollar ||
        key == LogicalKeyboardKey.percent ||
        key == LogicalKeyboardKey.ampersand ||
        key == LogicalKeyboardKey.asterisk ||
        key == LogicalKeyboardKey.parenthesisLeft ||
        key == LogicalKeyboardKey.parenthesisRight ||
        key == LogicalKeyboardKey.less ||
        key == LogicalKeyboardKey.greater ||
        key == LogicalKeyboardKey.question ||
        key == LogicalKeyboardKey.backspace) {
      return true;
    }

    return false;
  }

  // ────────────────────────────────────────────────
  //  Key event dispatch
  // ────────────────────────────────────────────────

  void onKeyEvent(KeyEvent event) {
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
      hasPrimaryFocus: true,
      showZapOverlay: showZapOverlay,
      onPlayPause: () => ref.read(playerServiceProvider).playOrPause(),
      onZapChannel: zapChannel,
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
      onToggleFullscreen: () => toggleOsFullscreen(),
      onToggleZap: () => setState(() => showZapOverlay = !showZapOverlay),
      onShowZap: () => setState(() => showZapOverlay = true),
      onBack: onBack,
      onToggleCaptions: () {
        final state = ref.read(playbackStateProvider).value;
        if (state != null) {
          showSubtitleTrackPicker(context, ref, state);
        }
      },
      onShowShortcuts: () {
        setState(() => showShortcutsHelp = !showShortcutsHelp);
      },
      onToggleLock: () => ref.read(playerLockedProvider.notifier).toggle(),
      onOpenGuide: () => ref.read(guideSplitProvider.notifier).toggle(),
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
}
