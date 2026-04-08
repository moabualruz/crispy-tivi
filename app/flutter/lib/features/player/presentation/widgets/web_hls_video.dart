/// Conditional export: uses the web implementation when compiling
/// for web, and a no-op stub on native platforms.
library;

export 'web_hls_video_stub.dart'
    if (dart.library.js_interop) 'web_hls_video_web.dart';
