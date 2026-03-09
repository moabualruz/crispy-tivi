import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'generated_placeholder.dart';
import 'skeleton_loader.dart';
import 'web_image.dart';
import '../../src/rust/api/all.dart' as rust_api;

/// Image widget with automatic fallback chain:
///
/// 1. [imageUrl] — original URL from provider
/// 2. tv-logos index resolution (for logos)
/// 3. Clearbit domain guessing (for logos)
/// 4. [blurHash] placeholder (if provided)
/// 5. [GeneratedPlaceholder] (first letter + gradient)
///
/// Handles null/empty URLs, 404s, and Network errors gracefully without caching.
///
/// On Flutter Web, set [SmartImage.proxyBaseUrl] once at startup (from
/// `main.dart`) to route all external images through the server's `/proxy`
/// endpoint, bypassing browser CORS restrictions.
class SmartImage extends StatelessWidget {
  /// Server base URL for the CORS image proxy (web only).
  ///
  /// Set this once in `main.dart` after `backend.init(...)` when running
  /// on web. Null on all native platforms — no proxy is used.
  ///
  /// Example: `SmartImage.proxyBaseUrl = 'http://127.0.0.1:8080';`
  static String? proxyBaseUrl;
  const SmartImage({
    super.key,
    // itemId and imageKind are accepted for backwards-compatibility but
    // are not used in build logic — planned for a future cache lookup.
    this.itemId = '',
    required this.title,
    this.imageUrl,
    this.imageKind = 'poster',
    this.fit = BoxFit.cover,
    this.icon,
    this.blurHash,
    this.placeholderAspectRatio,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  /// Item ID — accepted for call-site compatibility; not used in rendering.
  final String itemId;

  /// Title for the generated placeholder.
  final String title;

  /// Primary image URL from the data source.
  final String? imageUrl;

  /// Image kind — accepted for call-site compatibility; not used in rendering.
  final String imageKind;

  /// How the image should fit the container.
  final BoxFit fit;

  /// Fallback icon for the generated placeholder.
  final IconData? icon;

  /// Optional BlurHash string for placeholder rendering.
  ///
  /// When provided, a decoded BMP placeholder is shown while the
  /// full image loads, instead of a skeleton or letter avatar.
  /// Sourced from media server metadata (e.g. Jellyfin
  /// `ImageBlurHashes`).
  final String? blurHash;

  /// Aspect ratio for skeleton placeholder.
  final double? placeholderAspectRatio;

  /// Max width (px) for the decoded in-memory image cache.
  ///
  /// Pass the logical display width — Flutter handles DPR.
  /// Constrains memory: a 200px poster uses ~240KB vs 24MB
  /// at full resolution.
  final int? memCacheWidth;

  /// Max height (px) for the decoded in-memory image cache.
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return _buildCachedImage(context, imageUrl!);
    }

    // Attempt logo resolution chain if this is a TV channel logo
    // and no explicit image URL was provided via M3U metadata.
    if (imageKind == 'logo') {
      return _ResolvedLogoImage(
        title: title,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fallbackBuilder: _buildPlaceholder,
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildCachedImage(BuildContext context, String url) {
    final cleanUrl = url.trim();

    // 0.5. Sanitize protocols (reject sftp, relative paths, localized drives)
    if (!cleanUrl.startsWith('http://') &&
        !cleanUrl.startsWith('https://') &&
        !cleanUrl.startsWith('data:image/') &&
        !cleanUrl.startsWith('s:1:/images/')) {
      return _buildPlaceholder();
    }

    // 1. Handle inline Base64 data URIs or s:1: pseudo-URIs immediately
    if (cleanUrl.startsWith('data:image/') ||
        cleanUrl.startsWith('s:1:/images/')) {
      try {
        final String base64String;
        if (cleanUrl.startsWith('data:image/')) {
          base64String = cleanUrl.split(',').last;
        } else {
          // It's an s:1:/images/... URL-Safe base64 unpadded payload
          final raw = cleanUrl.replaceFirst('s:1:/images/', '');
          final padded = raw + ('=' * ((4 - raw.length % 4) % 4));
          base64String = padded.replaceAll('-', '+').replaceAll('_', '/');
        }

        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: fit,
          cacheWidth: memCacheWidth,
          cacheHeight: memCacheHeight,
          errorBuilder: (_, _, _) => _buildPlaceholder(),
        );
      } catch (e) {
        debugPrint('SmartImage Base64 decode error: $e');
        return _buildPlaceholder();
      }
    }

    // 2. Load basic network image exactly as provided directly from origin
    if (kIsWeb) {
      // Use HtmlElementView to bypass CanvasKit CORS errors.
      // Pass proxyBaseUrl so images are routed through /proxy when available.
      return createWebImage(
        cleanUrl,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        proxyBaseUrl: SmartImage.proxyBaseUrl,
      );
    }

    return _NetworkImageWithTimeout(
      url: cleanUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      blurHashBytes: _decodeBlurHash(),
      onBuildPlaceholder: _buildPlaceholder,
      onBuildSkeleton: _buildSkeletonLoader,
    );
  }

  Widget _buildSkeletonLoader() {
    return SkeletonCard(
      width: double.infinity,
      aspectRatio: placeholderAspectRatio ?? 2 / 3,
    );
  }

  Widget _buildPlaceholder() {
    // If we have a BlurHash, show that instead of letter avatar.
    final bmpBytes = _decodeBlurHash();
    if (bmpBytes != null) {
      return Image.memory(
        bmpBytes,
        fit: fit,
        errorBuilder:
            (_, _, _) => GeneratedPlaceholder(title: title, icon: icon),
      );
    }
    return GeneratedPlaceholder(title: title, icon: icon);
  }

  /// Decode [blurHash] to BMP bytes via Rust. Returns null on
  /// failure or if no hash is provided.
  Uint8List? _decodeBlurHash() {
    if (blurHash == null || blurHash!.isEmpty || kIsWeb) return null;
    try {
      return rust_api.decodeBlurhash(hash: blurHash!, width: 16, height: 16);
    } catch (_) {
      return null;
    }
  }
}

/// Timeout after which a still-loading image falls back to the
/// placeholder instead of showing the skeleton indefinitely.
///
/// 20 s gives slow connections time to load poster art without
/// flickering: skeleton → placeholder → actual image.
const Duration _kImageLoadTimeout = Duration(seconds: 20);

/// Wraps [Image.network] with a [_kImageLoadTimeout] fallback so that
/// images stuck in loading state eventually show the generated placeholder
/// instead of an indefinite grey skeleton.
class _NetworkImageWithTimeout extends StatefulWidget {
  const _NetworkImageWithTimeout({
    required this.url,
    required this.fit,
    required this.onBuildPlaceholder,
    required this.onBuildSkeleton,
    this.memCacheWidth,
    this.memCacheHeight,
    this.blurHashBytes,
  });

  final String url;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Uint8List? blurHashBytes;
  final Widget Function() onBuildPlaceholder;
  final Widget Function() onBuildSkeleton;

  @override
  State<_NetworkImageWithTimeout> createState() =>
      _NetworkImageWithTimeoutState();
}

class _NetworkImageWithTimeoutState extends State<_NetworkImageWithTimeout> {
  Timer? _loadingTimeout;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _loadingTimeout = Timer(_kImageLoadTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      fit: widget.fit,
      cacheWidth: widget.memCacheWidth,
      cacheHeight: widget.memCacheHeight,
      errorBuilder: (_, _, _) => widget.onBuildPlaceholder(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          _loadingTimeout?.cancel();
          return child;
        }
        if (_timedOut) return widget.onBuildPlaceholder();

        // Show BlurHash placeholder while loading if available.
        if (widget.blurHashBytes != null) {
          return Image.memory(
            widget.blurHashBytes!,
            fit: widget.fit,
            errorBuilder: (_, _, _) => widget.onBuildSkeleton(),
          );
        }

        return widget.onBuildSkeleton();
      },
    );
  }
}

/// Resolves a channel logo through the full fallback chain:
/// tv-logos index → Clearbit domain guessing → letter avatar.
///
/// Calls [resolveChannelLogo] (async DB lookup, <5 ms typical)
/// then either shows the resolved URL or falls through to
/// [_GuessedLogoImage] for Clearbit CDN guessing.
class _ResolvedLogoImage extends StatefulWidget {
  const _ResolvedLogoImage({
    required this.title,
    required this.fit,
    this.memCacheWidth,
    this.memCacheHeight,
    required this.fallbackBuilder,
  });

  final String title;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget Function() fallbackBuilder;

  @override
  State<_ResolvedLogoImage> createState() => _ResolvedLogoImageState();
}

class _ResolvedLogoImageState extends State<_ResolvedLogoImage> {
  String? _resolvedUrl;
  bool _checked = false;
  bool _resolvedUrlFailed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final url = await rust_api.resolveChannelLogo(name: widget.title);
      if (mounted) {
        setState(() {
          _resolvedUrl = url;
          _checked = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // While async resolution is in progress, show the letter placeholder.
    // The DB lookup is typically <5 ms so this is rarely visible.
    if (!_checked) return widget.fallbackBuilder();

    // tv-logos URL resolved — try to load it.
    if (_resolvedUrl != null && !_resolvedUrlFailed) {
      if (kIsWeb) {
        return createWebImage(
          _resolvedUrl!,
          fit: widget.fit,
          errorBuilder: (_, _, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _resolvedUrlFailed = true);
            });
            return _buildClearbitFallback();
          },
          proxyBaseUrl: SmartImage.proxyBaseUrl,
        );
      }

      return Image.network(
        _resolvedUrl!,
        fit: widget.fit,
        cacheWidth: widget.memCacheWidth,
        cacheHeight: widget.memCacheHeight,
        errorBuilder: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _resolvedUrlFailed = true);
          });
          return _buildClearbitFallback();
        },
      );
    }

    // No tv-logos match or URL failed — fall through to Clearbit.
    return _buildClearbitFallback();
  }

  Widget _buildClearbitFallback() {
    return _GuessedLogoImage(
      title: widget.title,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      fallbackBuilder: widget.fallbackBuilder,
    );
  }
}

class _GuessedLogoImage extends StatefulWidget {
  const _GuessedLogoImage({
    required this.title,
    required this.fit,
    this.memCacheWidth,
    this.memCacheHeight,
    required this.fallbackBuilder,
  });

  final String title;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget Function() fallbackBuilder;

  @override
  State<_GuessedLogoImage> createState() => _GuessedLogoImageState();
}

class _GuessedLogoImageState extends State<_GuessedLogoImage> {
  List<String>? _domains;
  int _currentIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDomains();
  }

  void _fetchDomains() {
    try {
      final domains = rust_api.guessLogoDomains(name: widget.title);
      setState(() {
        _domains = domains;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _domains = [];
        _loading = false;
      });
    }
  }

  void _onImageError() {
    if (!mounted) return;
    if (_domains == null || _currentIndex >= _domains!.length - 1) {
      setState(() {
        _currentIndex = _domains?.length ?? 0;
      });
      return;
    }
    setState(() {
      _currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Don't show a skeleton if we are just calling a sync Rust function,
      // but the state needs a moment to catch up.
      return widget.fallbackBuilder();
    }

    if (_domains == null ||
        _domains!.isEmpty ||
        _currentIndex >= _domains!.length) {
      return widget.fallbackBuilder();
    }

    final domain = _domains![_currentIndex];
    final url = 'https://logo.clearbit.com/$domain';

    if (kIsWeb) {
      return createWebImage(
        url,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onImageError());
          return widget.fallbackBuilder();
        },
        proxyBaseUrl: SmartImage.proxyBaseUrl,
      );
    }

    return Image.network(
      url,
      fit: widget.fit,
      cacheWidth: widget.memCacheWidth,
      cacheHeight: widget.memCacheHeight,
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onImageError());
        return widget.fallbackBuilder();
      },
    );
  }
}
