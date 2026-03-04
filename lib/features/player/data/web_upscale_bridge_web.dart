import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Web implementation of the upscale bridge.
///
/// Uses JS interop to communicate with `upscaler.js`
/// which handles WebGPU/WebGL video processing.
///
/// See `.ai/docs/project-specs/video_upscaling_spec.md` §3.3.

bool _initialized = false;
String? _activeMethod;

/// Initialize the web upscale pipeline.
///
/// Detects WebGPU/WebGL support. Returns true if any
/// upscale method is available.
Future<bool> initWebUpscaler() async {
  if (_initialized) return _activeMethod != null;
  _initialized = true;

  if (isWebGpuAvailable()) {
    _activeMethod = 'WebGPU CNN';
    return true;
  }

  if (isWebGl2Available()) {
    _activeMethod = 'WebGL FSR';
    return true;
  }

  return false;
}

/// Apply upscaling to the current video element.
Future<bool> applyWebUpscaling({
  required double scaleFactor,
  required String quality,
}) async {
  if (_activeMethod == null) return false;
  try {
    final upscaler = web.window.getProperty('crispyUpscaler'.toJS);
    if (upscaler == null) return false;
    (upscaler as JSObject).callMethod(
      'applyUpscaling'.toJS,
      scaleFactor.toJS,
      quality.toJS,
    );
    return true;
  } catch (_) {
    return false;
  }
}

/// Remove web upscaling and show raw video.
Future<void> removeWebUpscaling() async {
  try {
    final upscaler = web.window.getProperty('crispyUpscaler'.toJS);
    if (upscaler == null) return;
    (upscaler as JSObject).callMethod('removeUpscaling'.toJS);
  } catch (_) {
    // Ignore — may not be initialized.
  }
}

/// Check if WebGPU is available in this browser.
bool isWebGpuAvailable() {
  try {
    final gpu = web.window.getProperty('navigator'.toJS);
    if (gpu == null) return false;
    final gpuProp = (gpu as JSObject).getProperty('gpu'.toJS);
    return gpuProp != null;
  } catch (_) {
    return false;
  }
}

/// Check if WebGL 2 is available.
bool isWebGl2Available() {
  try {
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    final ctx = canvas.getContext('webgl2');
    return ctx != null;
  } catch (_) {
    return false;
  }
}

/// Get the active upscaling method name.
String? activeWebMethod() => _activeMethod;

/// Dispose resources.
Future<void> disposeWebUpscaler() async {
  _activeMethod = null;
  _initialized = false;
  try {
    final upscaler = web.window.getProperty('crispyUpscaler'.toJS);
    if (upscaler == null) return;
    (upscaler as JSObject).callMethod('dispose'.toJS);
  } catch (e) {
    debugPrint('WebUpscale: $e');
  }
}
