import 'fullscreen_helper_stub.dart'
    if (dart.library.js_interop) 'fullscreen_helper_web.dart';

/// Toggles browser fullscreen mode on web.
/// No-op on native platforms.
void toggleWebFullscreen() => platformToggleWebFullscreen();

/// Listen to fullscreen changes on web.
/// Returns a function to cancel the listener.
/// No-op on native platforms.
void Function() onWebFullscreenChange(
  void Function(bool isFullscreen) callback,
) => addWebFullscreenListener(callback);

/// Returns whether the browser is currently in
/// fullscreen mode. Always `false` on native.
bool isWebFullscreen() => platformIsWebFullscreen();
