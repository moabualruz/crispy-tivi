import 'package:flutter/widgets.dart';

import 'web_image_stub.dart' if (dart.library.js_interop) 'web_image_web.dart';

/// Renders an image using an HTML <img> tag on Flutter Web to bypass
/// CanvasKit CORS restrictions. On non-web platforms, it throws because
/// it should only be called when kIsWeb == true.
///
/// When [proxyBaseUrl] is provided (e.g. `http://127.0.0.1:8080`),
/// external image URLs are routed through the `/proxy` endpoint to
/// bypass browser CORS restrictions.
Widget createWebImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  String? proxyBaseUrl,
}) {
  return buildWebImage(
    url,
    fit: fit,
    errorBuilder: errorBuilder,
    proxyBaseUrl: proxyBaseUrl,
  );
}
