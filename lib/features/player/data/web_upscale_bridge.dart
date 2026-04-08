/// Conditional export: web upscaling implementation
/// on JS platforms, no-op stub on native.
///
/// See `the project video upscaling specification` §4.8.
library;

export 'web_upscale_bridge_stub.dart'
    if (dart.library.js_interop) 'web_upscale_bridge_web.dart';
