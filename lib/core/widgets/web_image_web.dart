import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class WebImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  /// Server base URL used to route images through the `/proxy` endpoint.
  ///
  /// When set, any `http`/`https` URL that doesn't already originate from
  /// this host is rewritten to `$proxyBaseUrl/proxy?url=<encoded>`.
  final String? proxyBaseUrl;

  const WebImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.proxyBaseUrl,
  });

  @override
  State<WebImage> createState() => _WebImageState();
}

class _WebImageState extends State<WebImage> {
  late String _viewId;
  static int _idCounter = 0;
  bool _hasError = false;

  /// Returns the URL to load, routing through the proxy when configured.
  ///
  /// The proxy is skipped for URLs that already originate from the server
  /// host (avoids double-proxying) and for non-http schemes (data: URIs).
  String _resolveUrl() {
    final base = widget.proxyBaseUrl;
    if (base != null &&
        widget.url.startsWith('http') &&
        !widget.url.startsWith(base)) {
      return '$base/proxy?url=${Uri.encodeComponent(widget.url)}';
    }
    return widget.url;
  }

  @override
  void initState() {
    super.initState();
    _viewId = 'web-img-${_idCounter++}-${widget.url.hashCode}';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final img =
          web.HTMLImageElement()
            ..src = _resolveUrl()
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.border = 'none'
            ..style.pointerEvents = 'none';

      switch (widget.fit) {
        case BoxFit.cover:
          img.style.objectFit = 'cover';
          break;
        case BoxFit.contain:
          img.style.objectFit = 'contain';
          break;
        case BoxFit.fill:
          img.style.objectFit = 'fill';
          break;
        case BoxFit.fitWidth:
        case BoxFit.fitHeight:
        case BoxFit.scaleDown:
        case BoxFit.none:
          img.style.objectFit = 'contain';
          break;
      }

      if (widget.errorBuilder != null) {
        img.onerror =
            ((web.Event _) {
              if (mounted && !_hasError) {
                setState(() {
                  _hasError = true;
                });
              }
            }).toJS;
      }

      return img;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && widget.errorBuilder != null) {
      return widget.errorBuilder!(
        context,
        Exception('HTML Image Load Error'),
        null,
      );
    }
    return IgnorePointer(child: HtmlElementView(viewType: _viewId));
  }
}

Widget buildWebImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  String? proxyBaseUrl,
}) {
  return WebImage(
    url: url,
    fit: fit,
    errorBuilder: errorBuilder,
    proxyBaseUrl: proxyBaseUrl,
  );
}
