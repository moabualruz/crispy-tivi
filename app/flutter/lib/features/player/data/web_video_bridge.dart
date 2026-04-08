/// Conditional export: web implementation on JS platforms,
/// no-op stub on native.
library;

export 'web_video_bridge_stub.dart'
    if (dart.library.js_interop) 'web_video_bridge_web.dart';
