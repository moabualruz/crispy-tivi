import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Web PiP implementation via the browser Picture-in-Picture API.
///
/// Calls `requestPictureInPicture()` on the first `<video>`
/// element found in the DOM. Firefox does not support this API
/// and will return `false` from [enterPiP].
class PipImpl {
  /// Enter browser PiP mode.
  Future<bool> enterPiP() async {
    try {
      final video = web.document.querySelector('video');
      if (video == null) return false;
      final promise = (video as JSObject).callMethod(
        'requestPictureInPicture'.toJS,
      );
      if (promise != null) {
        await (promise as JSPromise).toDart;
      }
      return true;
    } catch (_) {
      return false;
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
}
