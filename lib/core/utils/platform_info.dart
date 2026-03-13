/// Platform detection abstraction for features/ layer.
///
/// Features/ code MUST use this instead of importing `dart:io`
/// directly. Uses conditional imports so web builds get safe
/// defaults without touching `dart:io`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart'
    if (dart.library.js_interop) 'platform_info_web.dart'
    as impl;

/// Read-only view of the host OS.
///
/// Inject via [platformInfoProvider] in widgets/providers.
/// For non-Riverpod contexts, use [PlatformInfo.instance].
abstract class PlatformInfo {
  /// Singleton resolved at import time via conditional import.
  static final PlatformInfo instance = impl.createPlatformInfo();

  /// True when running on Microsoft Windows.
  bool get isWindows;

  /// True when running on Google Android.
  bool get isAndroid;

  /// True when running on Apple iOS.
  bool get isIOS;

  /// True when running on Apple macOS.
  bool get isMacOS;

  /// True when running on Linux.
  bool get isLinux;

  /// True when running on Google Fuchsia.
  bool get isFuchsia;

  /// Lower-case OS identifier (e.g. `'windows'`, `'android'`).
  String get operatingSystem;

  /// OS version string.
  String get operatingSystemVersion;
}

/// Riverpod provider exposing [PlatformInfo] for widget consumption.
final platformInfoProvider = Provider<PlatformInfo>(
  (ref) => PlatformInfo.instance,
);
