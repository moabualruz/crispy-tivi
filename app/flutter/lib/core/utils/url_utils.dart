import 'package:crispy_tivi/core/data/dart_algorithm_fallbacks.dart';

// URL normalization utilities.

/// Normalizes a server URL: trims, adds `http://` if missing, strips
/// trailing slash.
///
/// Delegates to [dartNormalizeServerUrl] — the canonical Dart fallback
/// that mirrors `crispy-core::algorithms::normalize_server_url`.
String normalizeServerUrl(String raw) => dartNormalizeServerUrl(raw);
