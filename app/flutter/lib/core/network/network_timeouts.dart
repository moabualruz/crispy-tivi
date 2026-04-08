/// Named timeout constants for all network/HTTP operations.
///
/// Centralises every `Duration` literal that appears in HTTP clients,
/// network-diagnostic checks, and media-server probes so they can be
/// changed in one place and remain self-documenting at call sites.
abstract final class NetworkTimeouts {
  /// Default connect timeout for the main HTTP client (Dio).
  ///
  /// Used by [HttpService] for regular IPTV / sync requests.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Default receive timeout for the main HTTP client (Dio).
  ///
  /// Large value accommodates slow IPTV servers sending big EPG / M3U
  /// playlist responses over poor connections.
  static const Duration receiveTimeout = Duration(seconds: 120);

  /// Short connect timeout for quick-probe operations.
  ///
  /// Used by server-probe providers (Jellyfin login, Quick Connect)
  /// and the M3U URL verifier where a fast response is expected.
  static const Duration fastConnectTimeout = Duration(seconds: 5);

  /// Short receive timeout for quick-probe operations.
  ///
  /// Paired with [fastConnectTimeout] for server-probe Dio instances.
  static const Duration fastReceiveTimeout = Duration(seconds: 5);

  /// Receive timeout used when verifying an M3U URL (HEAD request).
  ///
  /// Slightly longer than [fastReceiveTimeout] to allow slow CDN
  /// redirects while still failing quickly on dead URLs.
  static const Duration verifyReceiveTimeout = Duration(seconds: 10);

  /// Timeout for individual network-diagnostic checks.
  ///
  /// Applied to DNS lookup, TCP-connect latency, and download-speed
  /// steps in [NetworkDiagnosticsSheet].
  static const Duration diagCheckTimeout = Duration(seconds: 5);

  /// Timeout for the download-speed check in network diagnostics.
  ///
  /// Longer than [diagCheckTimeout] because the speed test downloads
  /// ~1 MB and may take several seconds on slow connections.
  static const Duration diagDownloadTimeout = Duration(seconds: 15);
}
