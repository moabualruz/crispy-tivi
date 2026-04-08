/// Apple MetalFX spatial upscaling bridge.
///
/// On native platforms: runtime Platform check for
/// macOS 13+ / iOS 16+ with Apple Silicon GPU.
/// On web: pure no-op stub.
///
/// See `the project video upscaling specification` Phase 3.
library;

export 'metalfx_bridge_stub.dart'
    if (dart.library.io) 'metalfx_bridge_native.dart';
