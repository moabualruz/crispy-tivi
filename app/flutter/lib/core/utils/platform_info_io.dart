/// Native (dart:io) implementation of [PlatformInfo].
library;

import 'dart:io' show Platform;

import 'platform_info.dart';

/// Factory used by the conditional import.
PlatformInfo createPlatformInfo() => _IoPlatformInfo();

class _IoPlatformInfo implements PlatformInfo {
  @override
  bool get isWindows => Platform.isWindows;
  @override
  bool get isAndroid => Platform.isAndroid;
  @override
  bool get isIOS => Platform.isIOS;
  @override
  bool get isMacOS => Platform.isMacOS;
  @override
  bool get isLinux => Platform.isLinux;
  @override
  bool get isFuchsia => Platform.isFuchsia;
  @override
  bool get isWeb => false;
  @override
  String get operatingSystem => Platform.operatingSystem;
  @override
  String get operatingSystemVersion => Platform.operatingSystemVersion;
}
