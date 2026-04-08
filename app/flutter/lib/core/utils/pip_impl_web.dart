import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Web PiP implementation via the browser Picture-in-Picture API.
///
/// Calls `requestPictureInPicture()` on the first `<video>`
/// element found in the DOM. Firefox does not support this API
/// and will return `(false, ...)` from [enterPiP].
class PipImpl {
  /// Whether PiP is supported on this platform.
  bool get isSupported {
    try {
      final doc = web.document as JSObject;
      final supported = doc['pictureInPictureEnabled'];
      if (supported != null && (supported as JSBoolean).toDart) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Callback for native PiP state changes (not used on web).
  void Function(bool isInPip)? onNativePipChanged;

  /// Enter browser PiP mode.
  Future<(bool, String?)> enterPiP({int? width, int? height}) async {
    try {
      final video = web.document.querySelector('video');
      if (video == null) return (false, 'No video element found');
      final promise = (video as JSObject).callMethod(
        'requestPictureInPicture'.toJS,
      );
      if (promise != null) {
        await (promise as JSPromise).toDart;
      }
      return (true, null);
    } catch (e) {
      return (false, 'Browser PiP not supported');
    }
  }

  /// Exit browser PiP mode.
  Future<void> exitPiP() async {
    try {
      final pipEl = (web.document as JSObject)['pictureInPictureElement'];
      if (pipEl != null && !pipEl.isNull) {
        final promise = (web.document as JSObject).callMethod(
          'exitPictureInPicture'.toJS,
        );
        if (promise != null) {
          await (promise as JSPromise).toDart;
        }
      }
    } catch (_) {
      // PiP not supported or already exited.
    }
  }

  /// Arm/disarm native auto-PiP (no-op on web).
  Future<void> setAutoPipReady({
    required bool ready,
    int? width,
    int? height,
  }) async {}

  /// Save PiP window bounds (no-op on web).
  Future<void> savePipBounds() async {}
}
