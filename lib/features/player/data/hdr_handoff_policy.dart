import 'dart:io';

import 'package:flutter/foundation.dart';

import 'android_hdr_player.dart';

/// Video format classification for HDR detection.
enum VideoFormat { sdr, hdr, hdr10, hdr10Plus, dolbyVision, hlg }

/// Determines whether the active stream should use the HDR native
/// player instead of media_kit.
///
/// Checks:
/// 1. Platform is Android
/// 2. Device display supports HDR output
/// 3. Stream's [VideoFormat] is not SDR
/// 4. The specific HDR format is supported by hardware
class HdrHandoffPolicy {
  /// Default constructor — call [init] before using [shouldHandoff].
  HdrHandoffPolicy();

  /// Test-only constructor that pre-populates HDR state without
  /// calling the native plugin.
  @visibleForTesting
  HdrHandoffPolicy.withState({
    required bool deviceSupportsHdr,
    required List<String> supportedFormats,
  }) : _deviceSupportsHdr = deviceSupportsHdr,
       _supportedFormats = supportedFormats,
       _initialized = true;

  /// Cached device HDR capability (checked once at init).
  bool _deviceSupportsHdr = false;
  List<String> _supportedFormats = [];

  /// Whether device HDR capability has been queried.
  bool get isInitialized => _initialized;
  bool _initialized = false;

  /// Whether the device supports HDR output.
  bool get deviceSupportsHdr => _deviceSupportsHdr;

  /// List of supported HDR format names (e.g., 'hdr10', 'dolby_vision').
  List<String> get supportedFormats => List.unmodifiable(_supportedFormats);

  /// Initialize by querying the native plugin.
  ///
  /// Safe to call on non-Android platforms — returns immediately
  /// with [deviceSupportsHdr] = false.
  Future<void> init() async {
    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }
    _deviceSupportsHdr = await AndroidHdrPlayer.isHdrSupported();
    _supportedFormats = await AndroidHdrPlayer.getSupportedFormats();
    _initialized = true;
  }

  /// Whether a handoff to the HDR player should occur for the
  /// given [videoFormat].
  bool shouldHandoff(VideoFormat? videoFormat) {
    if (!_deviceSupportsHdr) return false;
    if (videoFormat == null || videoFormat == VideoFormat.sdr) return false;

    switch (videoFormat) {
      case VideoFormat.hdr10:
        return _supportedFormats.contains('hdr10');
      case VideoFormat.hdr10Plus:
        return _supportedFormats.contains('hdr10_plus');
      case VideoFormat.dolbyVision:
        return _supportedFormats.contains('dolby_vision');
      case VideoFormat.hlg:
        return _supportedFormats.contains('hlg');
      case VideoFormat.hdr:
        return _supportedFormats.isNotEmpty;
      case VideoFormat.sdr:
        return false;
    }
  }
}
