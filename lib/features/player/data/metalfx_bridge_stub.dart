/// Web stub for MetalFX bridge.
///
/// MetalFX is Apple-only — all functions are no-ops
/// on web.
library;

/// Whether MetalFX is potentially available.
///
/// Always `false` on web.
bool get isMetalFxPlatform => false;

/// Initialize MetalFX spatial upscaler.
///
/// Always returns `false` on web.
Future<bool> initMetalFx() async => false;

/// Apply MetalFX spatial upscaling.
///
/// [scaleFactor] is the target scale (e.g. 2.0).
/// Always returns `false` on web.
Future<bool> applyMetalFx({required double scaleFactor}) async => false;

/// Remove MetalFX upscaling.
///
/// No-op on web.
Future<void> removeMetalFx() async {}

/// Dispose MetalFX resources.
///
/// No-op on web.
Future<void> disposeMetalFx() async {}
