// Native stub — web upscaling is a no-op.
//
// All methods return immediately with no effect.
// Native platforms use mpv's built-in shaders via
// UpscaleManager instead.

/// Initialize the web upscale pipeline.
/// No-op on native.
Future<bool> initWebUpscaler() async => false;

/// Apply upscaling to the video element.
/// No-op on native.
Future<bool> applyWebUpscaling({
  required double scaleFactor,
  required String quality,
}) async => false;

/// Remove web upscaling. No-op on native.
Future<void> removeWebUpscaling() async {}

/// Whether WebGPU is available. Always false on native.
bool isWebGpuAvailable() => false;

/// Whether WebGL 2 is available. Always false on native.
bool isWebGl2Available() => false;

/// Active web upscaling method name, or null.
String? activeWebMethod() => null;

/// Dispose the web upscaler. No-op on native.
Future<void> disposeWebUpscaler() async {}
