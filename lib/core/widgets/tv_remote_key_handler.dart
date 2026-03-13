import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Maps Android TV / Fire TV remote control media keys to callbacks.
///
/// Wraps [child] in a [Focus] widget that intercepts [KeyDownEvent]s
/// for media transport keys (play/pause, stop, rewind, fast-forward)
/// and channel navigation (channel up/down).
///
/// Only [KeyDownEvent] triggers callbacks — repeats and key-up events
/// are ignored to prevent duplicate invocations from held buttons.
///
/// Unhandled keys return [KeyEventResult.ignored] so they propagate
/// to other handlers in the focus tree.
///
/// Usage:
/// ```dart
/// TvRemoteKeyHandler(
///   onPlayPause: () => playerService.togglePlayPause(),
///   onStop: () => playerService.stop(),
///   onChannelUp: () => channelProvider.next(),
///   onChannelDown: () => channelProvider.previous(),
///   child: MyScreen(),
/// )
/// ```
class TvRemoteKeyHandler extends StatelessWidget {
  /// Creates a TV remote key handler.
  const TvRemoteKeyHandler({
    required this.child,
    this.onPlayPause,
    this.onStop,
    this.onRewind,
    this.onFastForward,
    this.onChannelUp,
    this.onChannelDown,
    this.onVolumeUp,
    this.onVolumeDown,
    this.autofocus = false,
    super.key,
  });

  /// The widget subtree to wrap.
  final Widget child;

  /// Called when media play/pause is pressed.
  final VoidCallback? onPlayPause;

  /// Called when media stop is pressed.
  final VoidCallback? onStop;

  /// Called when media rewind is pressed.
  final VoidCallback? onRewind;

  /// Called when media fast-forward is pressed.
  final VoidCallback? onFastForward;

  /// Called when channel up is pressed.
  final VoidCallback? onChannelUp;

  /// Called when channel down is pressed.
  final VoidCallback? onChannelDown;

  /// Called when volume up is pressed.
  ///
  /// Optional — system usually handles volume natively.
  final VoidCallback? onVolumeUp;

  /// Called when volume down is pressed.
  ///
  /// Optional — system usually handles volume natively.
  final VoidCallback? onVolumeDown;

  /// Whether this handler should request focus automatically.
  final bool autofocus;

  /// Maps a [LogicalKeyboardKey] to the corresponding callback.
  ///
  /// Returns the callback if the key is mapped, `null` otherwise.
  VoidCallback? _callbackForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.mediaPlayPause) return onPlayPause;
    if (key == LogicalKeyboardKey.mediaStop) return onStop;
    if (key == LogicalKeyboardKey.mediaRewind) return onRewind;
    if (key == LogicalKeyboardKey.mediaFastForward) return onFastForward;
    if (key == LogicalKeyboardKey.channelUp) return onChannelUp;
    if (key == LogicalKeyboardKey.channelDown) return onChannelDown;
    if (key == LogicalKeyboardKey.audioVolumeUp) return onVolumeUp;
    if (key == LogicalKeyboardKey.audioVolumeDown) return onVolumeDown;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        // Only handle key-down events — not repeats or key-up.
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final callback = _callbackForKey(event.logicalKey);
        if (callback != null) {
          callback();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
