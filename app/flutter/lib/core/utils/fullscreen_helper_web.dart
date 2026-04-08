// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// Toggles browser fullscreen on/off.
void platformToggleWebFullscreen() {
  final doc = web.document;
  if (doc.fullscreenElement != null) {
    doc.exitFullscreen();
  } else {
    doc.documentElement?.requestFullscreen();
  }
}

/// Listens for browser fullscreen changes and invokes
/// [callback] with the current fullscreen state.
/// Returns a cancel function.
void Function() addWebFullscreenListener(
  void Function(bool isFullscreen) callback,
) {
  final sub = web.EventStreamProviders.fullscreenChangeEvent
      .forTarget(web.document)
      .listen((_) {
        callback(web.document.fullscreenElement != null);
      });
  return () {
    sub.cancel();
  };
}

/// Returns whether the browser is currently in
/// fullscreen mode.
bool platformIsWebFullscreen() {
  return web.document.fullscreenElement != null;
}
